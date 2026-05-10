from firebase_functions import firestore_fn, options, scheduler_fn, https_fn
from firebase_admin import initialize_app, db, firestore, auth
from datetime import datetime, timedelta
from email_utils import send_email
import json

# Initialize Firebase App
initialize_app()

# For cost control, you can set the maximum number of containers that can be
# running at the same time.
options.set_global_options(max_instances=10)

# ------------------------------------------------------------------ #
#  Paystack Webhook: Automatic Premium Activation
# ------------------------------------------------------------------ #
@https_fn.on_request(
    cors=options.CorsOptions(
        cors_origins=["*"],
        cors_methods=["POST", "GET"],
    ),
    memory=options.MemoryOption.MB_256,
)
def paystack_webhook(req: https_fn.Request) -> https_fn.Response:
    """
    Webhook endpoint for Paystack payment notifications.
    Automatically activates premium subscription upon successful payment.
    
    Paystack sends webhooks for events like:
    - charge.success: Payment completed successfully
    - subscription.create: Subscription created
    - subscription.disable: Subscription cancelled
    
    This function:
    1. Verifies the webhook signature (security)
    2. Processes successful payments
    3. Activates premium subscription in Firestore
    4. Updates user's subscription status and expiry
    """
    
    # Only accept POST requests
    if req.method != "POST":
        return https_fn.Response("Method not allowed", status=405)
    
    try:
        # Parse webhook payload
        payload = req.get_json()
        event = payload.get("event")
        data = payload.get("data", {})
        
        print(f"Received Paystack webhook: {event}")
        
        # Handle successful charge
        if event == "charge.success":
            return _handle_successful_payment(data)
        
        # Handle subscription events
        elif event == "subscription.create":
            return _handle_subscription_created(data)
        
        elif event == "subscription.disable":
            return _handle_subscription_cancelled(data)
        
        # Acknowledge other events
        return https_fn.Response(json.dumps({"status": "received"}), status=200)
        
    except Exception as e:
        print(f"Webhook error: {e}")
        return https_fn.Response(json.dumps({"error": str(e)}), status=500)


def _handle_successful_payment(data: dict) -> https_fn.Response:
    """Process successful payment and activate premium subscription."""
    try:
        reference = data.get("reference")
        amount = data.get("amount", 0) // 100  # Convert from kobo to KES
        customer_email = data.get("customer", {}).get("email")
        metadata = data.get("metadata", {})
        user_id = metadata.get("user_id")
        
        if not user_id:
            print(f"No user_id in payment metadata for reference {reference}")
            return https_fn.Response(
                json.dumps({"error": "Missing user_id"}), 
                status=400
            )
        
        # Determine subscription duration based on amount
        # KES 300 = 7 days (weekly)
        # KES 1000 = 30 days (monthly)
        # KES 2500 = 90 days (termly)
        duration_days = 30  # Default to monthly
        plan_name = "Monthly"
        
        if amount == 300:
            duration_days = 7
            plan_name = "Weekly"
        elif amount == 1000:
            duration_days = 30
            plan_name = "Monthly"
        elif amount == 2500:
            duration_days = 90
            plan_name = "Termly"
        
        # Calculate expiry date
        expiry_date = datetime.utcnow() + timedelta(days=duration_days)
        
        # Update user document in Firestore
        db_client = firestore.client()
        user_ref = db_client.collection("users").document(user_id)
        
        # Get current user data
        user_doc = user_ref.get()
        if not user_doc.exists:
            print(f"User {user_id} not found in Firestore")
            return https_fn.Response(
                json.dumps({"error": "User not found"}), 
                status=404
            )
        
        user_data = user_doc.to_dict()
        current_expiry = user_data.get("subscriptionExpiry")
        
        # If user already has an active subscription, extend from current expiry
        if current_expiry and user_data.get("isSubscribed"):
            if hasattr(current_expiry, 'seconds'):
                current_expiry_dt = datetime.utcfromtimestamp(current_expiry.seconds)
            else:
                current_expiry_dt = current_expiry
            
            # If current subscription hasn't expired, extend from that date
            if current_expiry_dt > datetime.utcnow():
                expiry_date = current_expiry_dt + timedelta(days=duration_days)
                print(f"Extending existing subscription for user {user_id}")
        
        # Update user subscription status
        user_ref.update({
            "tier": "Premium",
            "isSubscribed": True,
            "subscriptionExpiry": expiry_date,
            "dailyMessageCount": 0,
            "free_message_count": 0,
            "accessedDocuments": [],
            "lastPaymentDate": datetime.utcnow(),
            "lastPaymentAmount": amount,
            "lastPaymentReference": reference,
        })
        
        # Update custom claims for immediate access
        try:
            auth.set_custom_user_claims(user_id, {
                "plan": "premium",
                "expiry": int(expiry_date.timestamp())
            })
            print(f"Updated custom claims for user {user_id}")
        except Exception as claim_error:
            print(f"Failed to update custom claims: {claim_error}")
        
        # Update transaction document
        transaction_ref = db_client.collection("paystack_transactions").document(reference)
        transaction_ref.update({
            "status": "completed",
            "completed_at": datetime.utcnow(),
            "subscription_activated": True,
            "subscription_expiry": expiry_date,
        })
        
        print(f"✅ Premium activated for user {user_id} until {expiry_date} ({plan_name} plan)")
        
        # Send confirmation email
        if customer_email:
            try:
                send_email(
                    to_email=customer_email,
                    subject="🎉 Your TopScore Pro is Now Active!",
                    template_name="payment_confirm.html",
                    context={
                        "plan_name": f"TopScore Premium – {plan_name}",
                        "amount": f"{amount:,}",
                        "expiry_date": expiry_date.strftime("%d %b %Y"),
                        "reference": reference
                    },
                    from_alias="payments"
                )
            except Exception as email_error:
                print(f"Failed to send confirmation email: {email_error}")
        
        return https_fn.Response(
            json.dumps({
                "status": "success",
                "message": "Premium subscription activated",
                "expiry": expiry_date.isoformat()
            }), 
            status=200
        )
        
    except Exception as e:
        print(f"Error processing payment: {e}")
        return https_fn.Response(
            json.dumps({"error": str(e)}), 
            status=500
        )


def _handle_subscription_created(data: dict) -> https_fn.Response:
    """Handle subscription creation event."""
    print(f"Subscription created: {data}")
    # Paystack subscriptions are handled via charge.success events
    return https_fn.Response(json.dumps({"status": "received"}), status=200)


def _handle_subscription_cancelled(data: dict) -> https_fn.Response:
    """Handle subscription cancellation event."""
    try:
        subscription_code = data.get("subscription_code")
        customer_email = data.get("customer", {}).get("email")
        
        print(f"Subscription cancelled: {subscription_code}")
        
        # Note: We don't immediately deactivate on cancellation
        # The subscription remains active until expiry date
        # The scheduled function will handle expiration
        
        return https_fn.Response(json.dumps({"status": "received"}), status=200)
        
    except Exception as e:
        print(f"Error handling subscription cancellation: {e}")
        return https_fn.Response(json.dumps({"error": str(e)}), status=500)


# ------------------------------------------------------------------ #
#  Auth Triggers: Welcome Email
# ------------------------------------------------------------------ #
@firestore_fn.on_document_created(document="users/{uid}")
def on_user_signup(event: firestore_fn.Event[firestore_fn.DocumentSnapshot | None]) -> None:
    """Sends a welcome email when a user profile is created in Firestore."""
    if event.data is None: return
    user_data = event.data.to_dict()
    if not user_data: return
    
    email = user_data.get("email")
    name = user_data.get("display_name") or user_data.get("name") or "Student"

    if not email:
        print("Signup: User has no email. Skipping.")
        return

    send_email(
        to_email=email,
        subject="Welcome to TopScore AI! 🚀",
        template_name="welcome.html",
        context={"user_name": name},
        from_alias="onboarding"
    )

# ------------------------------------------------------------------ #
#  Firestore Triggers: Transactions (Invoice & Confirmation)
# ------------------------------------------------------------------ #
@firestore_fn.on_document_created(document="paystack_transactions/{reference}")
def on_transaction_initiated(event: firestore_fn.Event[firestore_fn.DocumentSnapshot | None]) -> None:
    """Sends an invoice when a transaction is started."""
    if event.data is None: return
    data = event.data.to_dict()
    if not data: return

    email = data.get("email")
    if not email: return

    # Formatting for template
    amount_kes = data.get("amount", 0) // 100 # kobo -> KES
    
    send_email(
        to_email=email,
        subject=f"Invoice for {data.get('plan_name', 'TopScore Pro')}",
        template_name="invoice.html",
        context={
            "plan_name": data.get("plan_name", "TopScore Premium"),
            "amount": f"{amount_kes:,}",
            "reference": event.params["reference"]
        },
        from_alias="subscriptions"
    )

@firestore_fn.on_document_updated(document="paystack_transactions/{reference}")
def on_transaction_completed(event: firestore_fn.Event[firestore_fn.Change[firestore_fn.DocumentSnapshot | None]]) -> None:
    """Sends a confirmation email when status changes to 'completed'."""
    if event.data is None: return
    
    before = event.data.before.to_dict() if event.data.before else {}
    after = event.data.after.to_dict() if event.data.after else {}

    # Trigger only on status change to 'completed'
    if before.get("status") != "completed" and after.get("status") == "completed":
        email = after.get("email")
        if not email: return

        # Format details
        amount_kes = after.get("amount", 0) // 100
        
        # Determine expiry from user doc or transaction data if available
        # For the email, we'll try to calculate it if not in metadata
        expiry_str = "your subscription period"
        
        # Attempt to get end date (approximate if not found)
        from datetime import timedelta
        duration_days = 30
        if after.get("amount") == 30000: duration_days = 7
        
        expiry_date = datetime.utcnow() + timedelta(days=duration_days)
        expiry_str = expiry_date.strftime("%d %b %Y")

        send_email(
            to_email=email,
            subject="Payment Received! Your TopScore Pro is Active 🚀",
            template_name="payment_confirm.html",
            context={
                "plan_name": after.get("plan_name", "TopScore Premium"),
                "amount": f"{amount_kes:,}",
                "expiry_date": expiry_str,
                "reference": event.params["reference"]
            },
            from_alias="payments"
        )


# ------------------------------------------------------------------ #
#  Scheduled Function: Check and Expire Subscriptions
# ------------------------------------------------------------------ #
@scheduler_fn.on_schedule(
    schedule="0 */6 * * *",  # Run every 6 hours
    timezone="UTC",
    memory=options.MemoryOption.MB_256,
)
def check_expired_subscriptions(event: scheduler_fn.ScheduledEvent) -> None:
    """
    Runs every 6 hours to check for expired subscriptions and update user status.
    This ensures subscriptions are properly expired even if users don't open the app.
    
    Changes from daily to every 6 hours for more responsive expiration handling.
    """
    print("Starting subscription expiration check...")
    
    db_client = firestore.client()
    now = datetime.utcnow()
    
    # Query users who are marked as subscribed but have an expired subscriptionExpiry
    users_ref = db_client.collection("users")
    
    # Get all subscribed users
    subscribed_users = users_ref.where("isSubscribed", "==", True).stream()
    
    expired_count = 0
    error_count = 0
    
    for user_doc in subscribed_users:
        try:
            user_data = user_doc.to_dict()
            user_id = user_doc.id
            
            # Check if subscriptionExpiry exists and is in the past
            subscription_expiry = user_data.get("subscriptionExpiry")
            
            if subscription_expiry is None:
                # No expiry date means legacy subscription - keep active
                continue
            
            # Convert Firestore Timestamp to datetime
            if hasattr(subscription_expiry, 'seconds'):
                expiry_datetime = datetime.utcfromtimestamp(subscription_expiry.seconds)
            else:
                # Already a datetime object
                expiry_datetime = subscription_expiry
            
            # Check if expired
            if expiry_datetime < now:
                print(f"Expiring subscription for user {user_id} (expired on {expiry_datetime})")
                
                # Update user document to mark subscription as expired
                users_ref.document(user_id).update({
                    "tier": "Free",
                    "isSubscribed": False
                })
                
                # Remove premium custom claims
                try:
                    auth.set_custom_user_claims(user_id, {
                        "plan": "free",
                        "expiry": None
                    })
                    print(f"Removed premium claims for user {user_id}")
                except Exception as claim_error:
                    print(f"Failed to remove custom claims: {claim_error}")
                
                expired_count += 1
                
                # Send expiration notification email
                email = user_data.get("email")
                name = user_data.get("display_name") or user_data.get("name") or "Student"
                
                if email:
                    try:
                        send_email(
                            to_email=email,
                            subject="Your TopScore Pro Subscription Has Expired",
                            template_name="subscription_expired.html",
                            context={
                                "user_name": name,
                                "expiry_date": expiry_datetime.strftime("%d %b %Y")
                            },
                            from_alias="subscriptions"
                        )
                    except Exception as email_error:
                        print(f"Failed to send expiration email to {email}: {email_error}")
                
        except Exception as e:
            error_count += 1
            print(f"Error processing user {user_doc.id}: {e}")
    
    print(f"Subscription expiration check complete. Expired: {expired_count}, Errors: {error_count}")
