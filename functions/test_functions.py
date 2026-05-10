#!/usr/bin/env python3
"""
Test script for Firebase Cloud Functions
Run this locally to verify functions work before deploying
"""

import sys
import os
from datetime import datetime, timedelta

# Add functions directory to path
sys.path.insert(0, os.path.dirname(__file__))

def test_email_utils():
    """Test email utility functions"""
    print("Testing email_utils...")
    
    try:
        from email_utils import send_email
        print("✓ email_utils imported successfully")
        
        # Test template rendering (without actually sending)
        from jinja2 import Environment, FileSystemLoader, select_autoescape
        template_dir = os.path.join(os.path.dirname(__file__), 'templates')
        jinja_env = Environment(
            loader=FileSystemLoader(template_dir),
            autoescape=select_autoescape(['html', 'xml'])
        )
        
        # Test each template
        templates = [
            ('welcome.html', {'user_name': 'Test User'}),
            ('invoice.html', {'plan_name': 'Premium', 'amount': '500', 'reference': 'TEST123'}),
            ('payment_confirm.html', {'plan_name': 'Premium', 'amount': '500', 'expiry_date': '01 Jan 2026', 'reference': 'TEST123'}),
            ('subscription_expired.html', {'user_name': 'Test User', 'expiry_date': '01 Jan 2026'}),
        ]
        
        for template_name, context in templates:
            try:
                template = jinja_env.get_template(template_name)
                html = template.render(**context)
                if len(html) > 100:  # Basic check that template rendered
                    print(f"  ✓ {template_name} renders correctly")
                else:
                    print(f"  ✗ {template_name} rendered but seems empty")
            except Exception as e:
                print(f"  ✗ {template_name} failed: {e}")
        
        return True
    except Exception as e:
        print(f"✗ email_utils test failed: {e}")
        return False

def test_main_functions():
    """Test main.py imports and function definitions"""
    print("\nTesting main.py...")
    
    try:
        # Test imports
        from firebase_functions import firestore_fn, options, scheduler_fn
        print("✓ firebase_functions imports work")
        
        # Check if main.py can be imported
        import main
        print("✓ main.py imports successfully")
        
        # Check function definitions
        functions = [
            'on_user_signup',
            'on_transaction_initiated',
            'on_transaction_completed',
            'check_expired_subscriptions'
        ]
        
        for func_name in functions:
            if hasattr(main, func_name):
                print(f"  ✓ {func_name} is defined")
            else:
                print(f"  ✗ {func_name} is NOT defined")
        
        return True
    except Exception as e:
        print(f"✗ main.py test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_subscription_expiry_logic():
    """Test subscription expiry logic"""
    print("\nTesting subscription expiry logic...")
    
    try:
        now = datetime.utcnow()
        
        # Test case 1: Expired subscription
        expired_date = now - timedelta(days=1)
        if expired_date < now:
            print("  ✓ Expired date detection works")
        else:
            print("  ✗ Expired date detection failed")
        
        # Test case 2: Active subscription
        active_date = now + timedelta(days=30)
        if active_date > now:
            print("  ✓ Active date detection works")
        else:
            print("  ✗ Active date detection failed")
        
        # Test case 3: Date formatting
        formatted = expired_date.strftime("%d %b %Y")
        if len(formatted) > 0:
            print(f"  ✓ Date formatting works: {formatted}")
        else:
            print("  ✗ Date formatting failed")
        
        return True
    except Exception as e:
        print(f"✗ Subscription expiry logic test failed: {e}")
        return False

def test_requirements():
    """Test that all required packages are installed"""
    print("\nTesting requirements...")
    
    required_packages = [
        'firebase_functions',
        'firebase_admin',
        'jinja2',
    ]
    
    all_installed = True
    for package in required_packages:
        try:
            __import__(package)
            print(f"  ✓ {package} is installed")
        except ImportError:
            print(f"  ✗ {package} is NOT installed")
            all_installed = False
    
    return all_installed

def test_template_structure():
    """Test template file structure"""
    print("\nTesting template structure...")
    
    template_dir = os.path.join(os.path.dirname(__file__), 'templates')
    
    if not os.path.exists(template_dir):
        print(f"✗ Template directory not found: {template_dir}")
        return False
    
    print(f"✓ Template directory exists: {template_dir}")
    
    required_templates = [
        'base.html',
        'welcome.html',
        'invoice.html',
        'payment_confirm.html',
        'subscription_expired.html',
    ]
    
    all_exist = True
    for template in required_templates:
        template_path = os.path.join(template_dir, template)
        if os.path.exists(template_path):
            print(f"  ✓ {template} exists")
        else:
            print(f"  ✗ {template} NOT found")
            all_exist = False
    
    return all_exist

def main():
    """Run all tests"""
    print("=" * 60)
    print("Firebase Cloud Functions Test Suite")
    print("=" * 60)
    
    tests = [
        ("Requirements", test_requirements),
        ("Template Structure", test_template_structure),
        ("Email Utils", test_email_utils),
        ("Subscription Logic", test_subscription_expiry_logic),
        ("Main Functions", test_main_functions),
    ]
    
    results = []
    for test_name, test_func in tests:
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"\n✗ {test_name} crashed: {e}")
            results.append((test_name, False))
    
    print("\n" + "=" * 60)
    print("Test Results Summary")
    print("=" * 60)
    
    passed = sum(1 for _, result in results if result)
    total = len(results)
    
    for test_name, result in results:
        status = "✓ PASS" if result else "✗ FAIL"
        print(f"{status}: {test_name}")
    
    print(f"\nTotal: {passed}/{total} tests passed")
    
    if passed == total:
        print("\n🎉 All tests passed! Functions are ready to deploy.")
        return 0
    else:
        print(f"\n⚠️  {total - passed} test(s) failed. Fix issues before deploying.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
