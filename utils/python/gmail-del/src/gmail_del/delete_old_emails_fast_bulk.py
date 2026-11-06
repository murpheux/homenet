#!/usr/bin/env python3
import os
import pickle
from google.auth.transport.requests import Request
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

SCOPES = ['https://mail.google.com/']

def get_service():
    if os.path.exists('token.pickle'):
        with open('token.pickle', 'rb') as t:
            creds = pickle.load(t)
    else:
        flow = InstalledAppFlow.from_client_secrets_file('credentials.json', SCOPES)
        creds = flow.run_local_server(port=0)
        with open('token.pickle', 'wb') as t:
            pickle.dump(creds, t)
    return build('gmail', 'v1', credentials=creds)

def fast_delete(service, date='2014/01/01'):
    """Fast bulk delete - 1000 messages per API call"""
    query = f"before:{date}"
    total = 0
    page_token = None
    
    while True:
        # Get 500 messages at a time
        results = service.users().messages().list(
            userId='me', q=query, maxResults=500, pageToken=page_token
        ).execute()
        
        messages = results.get('messages', [])
        if not messages:
            break
        
        # Get all IDs
        ids = [m['id'] for m in messages]
        
        # Delete in chunks of 100 using batch
        for i in range(0, len(ids), 100):
            batch = service.new_batch_http_request()
            for msg_id in ids[i:i+100]:
                batch.add(service.users().messages().delete(userId='me', id=msg_id))
            batch.execute()
            total += len(ids[i:i+100])
            print(f"Deleted {total} emails...")
        
        page_token = results.get('nextPageToken')
    
    print(f"\n✅ Complete! Deleted {total} emails!")

if __name__ == '__main__':
    service = get_service()
    fast_delete(service)