from firebase_functions import firestore_fn, options
from firebase_admin import initialize_app, db, firestore
from datetime import datetime
from email_utils import send_email

# Initialize Firebase App
initialize_app()

# For cost control, you can set the maximum number of containers that can be
# running at the same time.
options.set_global_options(max_instances=10)

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
