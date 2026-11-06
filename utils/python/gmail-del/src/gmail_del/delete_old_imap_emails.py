import imaplib
import email
from email.header import decode_header
import datetime
import getpass
import sys

def delete_emails_before_date_imap(email_address, password, date_threshold='01-Jan-2012'):
    """
    Delete emails before a specific date using IMAP
    
    Args:
        email_address: Your Gmail address
        password: Your Gmail app password (not your regular password)
        date_threshold: Date in format like '01-Jan-2012'
    """
    
    # Gmail IMAP settings
    IMAP_SERVER = 'imap.gmail.com'
    IMAP_PORT = 993
    
    try:
        # Connect to Gmail
        print("Connecting to Gmail...")
        mail = imaplib.IMAP4_SSL(IMAP_SERVER, IMAP_PORT)
        mail.login(email_address, password)
        print("Connected successfully!")
        
        # Select the mailbox (INBOX is default)
        mail.select('INBOX')
        
        # Search for emails before the specified date
        # IMAP date format: DD-Mon-YYYY
        search_criteria = f'(BEFORE "{date_threshold}")'
        print(f"Searching for emails before {date_threshold}...")
        
        result, message_ids = mail.search(None, search_criteria)
        
        if result != 'OK':
            print("No emails found matching the criteria.")
            return
        
        email_ids = message_ids[0].split()
        total_emails = len(email_ids)
        
        print(f"Found {total_emails} emails to delete.")
        
        if total_emails == 0:
            print("No old emails found.")
            return
        
        # Show preview of first few emails
        preview_count = min(5, total_emails)
        print(f"\nPreview of first {preview_count} emails to be deleted:")
        print("-" * 60)
        
        for i in range(preview_count):
            result, msg_data = mail.fetch(email_ids[i], '(RFC822)')
            if result == 'OK':
                raw_email = msg_data[0][1]
                msg = email.message_from_bytes(raw_email)
                
                # Decode subject
                subject = decode_header(msg.get('Subject', 'No Subject'))[0][0]
                if isinstance(subject, bytes):
                    subject = subject.decode()
                
                from_addr = msg.get('From', 'Unknown')
                date = msg.get('Date', 'Unknown')
                
                print(f"{i+1}. From: {from_addr[:50]}")
                print(f"   Subject: {subject[:50]}")
                print(f"   Date: {date[:50]}")
                print()
        
        # Ask for confirmation
        print(f"\n⚠️  WARNING: You are about to permanently delete {total_emails} emails!")
        print(f"This action cannot be undone. Emails will be moved to Trash.")
        
        confirmation = input(f"\nType 'DELETE {total_emails}' to confirm deletion: ")
        
        if confirmation == f'DELETE {total_emails}':
            print("\nDeleting emails...")
            deleted_count = 0
            
            # Delete in batches to avoid rate limits
            batch_size = 100
            for i in range(0, total_emails, batch_size):
                batch = email_ids[i:i+batch_size]
                for email_id in batch:
                    mail.store(email_id, '+FLAGS', '\\Deleted')
                    deleted_count += 1
                    
                    if deleted_count % 10 == 0:
                        print(f"Deleted {deleted_count}/{total_emails} emails...")
                
                # Expunge after each batch
                mail.expunge()
            
            print(f"\n✅ Successfully deleted {deleted_count} emails!")
        else:
            print("\n❌ Deletion cancelled. No emails were deleted.")
        
        # Close connection
        mail.close()
        mail.logout()
        
    except imaplib.IMAP4.error as e:
        print(f"\n❌ IMAP Error: {e}")
        print("\nTroubleshooting tips:")
        print("1. Make sure 'Less secure app access' is ENABLED or use an App Password")
        print("2. Enable IMAP in Gmail Settings → Forwarding and POP/IMAP")
        print("3. If using 2FA, create an App Specific Password")
        
    except Exception as e:
        print(f"\n❌ Error: {e}")

def main():
    """Main function"""
    print("=" * 60)
    print("Gmail Old Email Deletion Tool (IMAP Version)")
    print("=" * 60)
    
    print("\n📧 IMPORTANT SETUP INSTRUCTIONS:")
    print("1. Go to Gmail Settings → Forwarding and POP/IMAP")
    print("2. Enable IMAP access")
    print("3. If you have 2-Factor Authentication, create an App Password:")
    print("   - Go to https://myaccount.google.com/apppasswords")
    print("   - Generate password for 'Mail'")
    print("\n4. If no 2FA, you may need to enable 'Allow less secure apps'")
    print("   (Note: Google is phasing this out, App Password is recommended)")
    
    print("\n" + "=" * 60)
    
    # Get credentials
    email = input("\nEnter your Gmail address: ").strip()
    password = getpass.getpass("Enter your Gmail App Password (hidden): ")
    
    # Date threshold
    print("\nDate format should be: DD-Mon-YYYY (e.g., 01-Jan-2012)")
    date_threshold = input("Enter date threshold (press Enter for default '01-Jan-2012'): ").strip()
    
    if not date_threshold:
        date_threshold = '01-Jan-2012'
    
    # Validate date format (simple check)
    try:
        datetime.datetime.strptime(date_threshold, '%d-%b-%Y')
    except ValueError:
        print("\n❌ Invalid date format! Please use DD-Mon-YYYY (e.g., 01-Jan-2012)")
        return
    
    # Confirm
    print(f"\nYou are about to delete ALL emails before {date_threshold}")
    print("This includes emails in your INBOX only (not other labels/folders)")
    
    final_confirm = input("\nType 'YES' to continue: ")
    
    if final_confirm == 'YES':
        delete_emails_before_date_imap(email, password, date_threshold)
    else:
        print("\nOperation cancelled.")

if __name__ == '__main__':
    main()