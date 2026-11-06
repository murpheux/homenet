import os
import pickle
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

# If modifying these scopes, delete the file token.pickle.
#SCOPES = ['https://www.googleapis.com/auth/gmail.modify']
SCOPES = ['https://mail.google.com/']

def get_gmail_service():
    """Authenticate and return Gmail API service"""
    creds = None
    
    # Token file stores the user's access and refresh tokens
    if os.path.exists('token.pickle'):
        with open('token.pickle', 'rb') as token:
            creds = pickle.load(token)
    
    # If there are no (valid) credentials available, let the user log in
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            # Download client_secret.json from Google Cloud Console
            if not os.path.exists('credentials.json'):
                print("Error: credentials.json not found!")
                print("Please download OAuth 2.0 credentials from Google Cloud Console")
                return None
            
            flow = InstalledAppFlow.from_client_secrets_file(
                'credentials.json', SCOPES)
            creds = flow.run_local_server(port=0)
        
        # Save credentials for next run
        with open('token.pickle', 'wb') as token:
            pickle.dump(creds, token)
    
    return build('gmail', 'v1', credentials=creds)

def delete_emails_before_date(service, date_threshold='2013/11/01', batch_size=100):
    """
    Delete all emails received before the specified date
    
    Args:
        service: Gmail API service
        date_threshold: Date threshold in 'YYYY/MM/DD' format
        batch_size: Number of emails to process in each batch
    """
    # Query for emails before the specified date
    query = f"before:{date_threshold}"
    
    print(f"Searching for emails before {date_threshold}...")
    print(f"Query: {query}")
    
    try:
        total_deleted = 0
        
        while True:
            # Search for messages
            results = service.users().messages().list(
                userId='me', 
                q=query, 
                maxResults=batch_size
            ).execute()
            
            messages = results.get('messages', [])
            
            if not messages:
                print("No more messages found.")
                break
            
            print(f"Found {len(messages)} messages in this batch")
            
            # Delete messages in batch
            for message in messages:
                try:
                    # Delete the message
                    service.users().messages().delete(
                        userId='me', 
                        id=message['id']
                    ).execute()
                    total_deleted += 1
                    print(f"Deleted message {total_deleted}: {message['id']}")
                    
                except HttpError as error:
                    if error.resp.status == 404:
                        print(f"Message {message['id']} already deleted")
                    elif error.resp.status == 403:
                        print(f"Permission error deleting message {message['id']}: {error}")
                        exit(1)
                    else:
                        print(f"Error deleting message {message['id']}: {error}")
            
            print(f"Progress: {total_deleted} messages deleted so far...")
            
            # Break if there are no more pages
            if 'nextPageToken' not in results:
                break
        
        print(f"\nDeletion complete! Total deleted: {total_deleted} messages")
        
    except HttpError as error:
        print(f"An error occurred: {error}")
        return False
    
    return True

def preview_emails_before_date(service, date_threshold='2013/11/01', max_results=10):
    """
    Preview emails that would be deleted (for safety)
    
    Args:
        service: Gmail API service
        date_threshold: Date threshold in 'YYYY/MM/DD' format
        max_results: Maximum number of emails to preview
    """
    query = f"before:{date_threshold}"
    
    print(f"\nPreviewing up to {max_results} emails before {date_threshold}:")
    print("-" * 60)
    
    try:
        results = service.users().messages().list(
            userId='me', 
            q=query, 
            maxResults=max_results
        ).execute()
        
        messages = results.get('messages', [])
        
        if not messages:
            print("No emails found before the specified date.")
            return
        
        for i, message in enumerate(messages, 1):
            msg = service.users().messages().get(
                userId='me', 
                id=message['id'],
                format='metadata',
                metadataHeaders=['From', 'Subject', 'Date']
            ).execute()
            
            headers = msg['payload']['headers']
            from_addr = next((h['value'] for h in headers if h['name'] == 'From'), 'Unknown')
            subject = next((h['value'] for h in headers if h['name'] == 'Subject'), 'No Subject')
            date = next((h['value'] for h in headers if h['name'] == 'Date'), 'Unknown')
            
            print(f"{i}. From: {from_addr[:50]}")
            print(f"   Subject: {subject[:50]}")
            print(f"   Date: {date[:50]}")
            print(f"   ID: {message['id']}")
            print()
            
    except HttpError as error:
        print(f"An error occurred during preview: {error}")

def main():
    """Main function to run the email deletion process"""
    print("=" * 60)
    print("Gmail Old Email Deletion Tool")
    print("=" * 60)
    
    # Date threshold
    date_threshold = '2013/11/01'
    
    # Get Gmail service
    print("\nAuthenticating with Gmail...")
    service = get_gmail_service()
    
    if not service:
        print("Failed to authenticate. Please check your credentials.")
        return
    
    print("Authentication successful!")
    
    # Show preview of emails to be deleted
    preview_emails_before_date(service, date_threshold)
    
    # Ask for confirmation
    print("\n⚠️  WARNING: This will permanently delete all emails received")
    print(f"   before {date_threshold}. This action cannot be undone!")
    
    confirmation = input("\nType 'DELETE ALL' to confirm deletion: ")
    
    if confirmation == 'DELETE ALL':
        print("\nStarting deletion process...")
        delete_emails_before_date(service, date_threshold)
    else:
        print("\nOperation cancelled. No emails were deleted.")

if __name__ == '__main__':
    main()