import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from jinja2 import Environment, FileSystemLoader, select_autoescape

# Setup Jinja2 environment
template_dir = os.path.join(os.path.dirname(__file__), 'templates')
jinja_env = Environment(
    loader=FileSystemLoader(template_dir),
    autoescape=select_autoescape(['html', 'xml'])
)

SMTP_SERVER = "smtp.gmail.com"
SMTP_PORT = 587
# These should be set via Firebase Secrets or Env Vars
SMTP_USER = os.getenv("SMTP_USER", "admin@topscoreapp.ai")
SMTP_PASS = os.getenv("SMTP_PASSWORD", "")

def send_email(to_email: str, subject: str, template_name: str, context: dict, from_alias: str = "onboarding"):
    """
    Sends a branded HTML email using Jinja2 templates.
    from_alias: 'onboarding', 'subscriptions', or 'payments'
    """
    if not SMTP_PASS:
        print(f"Skipping email to {to_email}: SMTP_PASSWORD not configured.")
        return False

    # Map aliases to full addresses
    aliases = {
        "onboarding": "onboarding@topscoreapp.ai",
        "subscriptions": "subscriptions@topscoreapp.ai",
        "payments": "payments@topscoreapp.ai"
    }
    from_address = aliases.get(from_alias, aliases["onboarding"])
    from_name = {
        "onboarding": "TopScore AI Onboarding",
        "subscriptions": "TopScore AI Subscriptions",
        "payments": "TopScore AI Payments"
    }.get(from_alias, "TopScore AI")

    try:
        # Render template
        template = jinja_env.get_template(template_name)
        html_content = template.render(**context)

        # Create message
        msg = MIMEMultipart('alternative')
        msg['Subject'] = subject
        msg['From'] = f"{from_name} <{from_address}>"
        msg['To'] = to_email

        # Attach HTML
        msg.attach(MIMEText(html_content, 'html'))

        # Send via SMTP
        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_USER, SMTP_PASS)
            server.send_message(msg)
        
        print(f"Email sent successfully to {to_email} via {from_address}")
        return True

    except Exception as e:
        print(f"Failed to send email to {to_email}: {e}")
        return False
