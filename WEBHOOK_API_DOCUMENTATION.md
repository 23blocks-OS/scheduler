# Cal.com Webhook API Documentation

## Overview
This document provides comprehensive information about the webhook payloads that Cal.com sends for various scheduling events. Your API endpoint should be prepared to handle these webhook payloads when subscribed to the corresponding events.

## Webhook Events

Cal.com supports the following webhook trigger events:

### Core Events
- `BOOKING_CANCELLED` - Fired when a booking is cancelled
- `BOOKING_CREATED` - Fired when a new booking is successfully created
- `BOOKING_RESCHEDULED` - Fired when an existing booking is rescheduled
- `BOOKING_REJECTED` - Fired when a booking request is rejected
- `BOOKING_REQUESTED` - Fired when a booking request is made (for events requiring confirmation)
- `BOOKING_PAYMENT_INITIATED` - Fired when payment is initiated for a booking
- `BOOKING_PAID` - Fired when payment is successfully completed
- `BOOKING_NO_SHOW_UPDATED` - Fired when no-show status is updated
- `MEETING_ENDED` - Fired when a meeting ends
- `MEETING_STARTED` - Fired when a meeting starts
- `RECORDING_READY` - Fired when a recording is available
- `RECORDING_TRANSCRIPTION_GENERATED` - Fired when transcription is generated
- `INSTANT_MEETING` - Fired when an instant meeting is created
- `OOO_CREATED` - Fired when an out-of-office entry is created
- `AFTER_HOSTS_CAL_VIDEO_NO_SHOW` - Fired after hosts don't join Cal video
- `AFTER_GUESTS_CAL_VIDEO_NO_SHOW` - Fired after guests don't join Cal video

### Form Events
- `FORM_SUBMITTED` - Fired when a form is submitted with an event booked
- `FORM_SUBMITTED_NO_EVENT` - Fired when a form is submitted without booking an event

## Webhook Payload Structure

### Standard Payload Format

All webhooks follow this base structure:

```json
{
  "triggerEvent": "BOOKING_CREATED",
  "createdAt": "2023-05-24T09:30:00.538Z",
  "payload": {
    // Event-specific data (see below)
  }
}
```

### Event Payload Fields

The `payload` object contains the following fields for booking-related events:

#### Basic Event Information
```json
{
  "type": "string",                    // Event type slug (e.g., "60min")
  "title": "string",                   // Event title
  "description": "string",             // Event description
  "additionalNotes": "string",         // Additional notes from booker
  "startTime": "2023-05-25T09:30:00Z", // ISO 8601 format
  "endTime": "2023-05-25T10:30:00Z",   // ISO 8601 format
  "uid": "string",                     // Unique booking identifier
  "bookingId": 123,                    // Numeric booking ID
  "status": "ACCEPTED",                // Booking status: ACCEPTED, CANCELLED, PENDING, REJECTED
  "location": "string",                // Meeting location
  "conferenceData": {},                // Conference details (if applicable)
  "metadata": {}                       // Additional metadata including videoCallUrl for video meetings
}
```

#### Event Type Details
```json
{
  "eventTypeId": 123,
  "eventTitle": "string",              // Event type title
  "eventDescription": "string",        // Event type description
  "requiresConfirmation": boolean,     // Whether confirmation is required
  "price": 0,                         // Price in smallest currency unit
  "currency": "usd",                  // Currency code
  "length": 60                        // Duration in minutes
}
```

#### Organizer Information
```json
{
  "organizer": {
    "id": 123,
    "name": "string",
    "email": "email@example.com",
    "username": "string",
    "timeZone": "America/New_York",
    "language": {
      "locale": "en"
    },
    "timeFormat": "h:mma",             // 12h or 24h format
    "utcOffset": -300                  // Offset in minutes (added at runtime)
  }
}
```

#### Attendees Information
```json
{
  "attendees": [
    {
      "name": "string",
      "email": "email@example.com",
      "timeZone": "America/New_York",
      "language": {
        "locale": "en"
      },
      "phoneNumber": "string",          // Optional
      "utcOffset": -300                 // Added at runtime
    }
  ]
}
```

#### Team Information (for team events)
```json
{
  "team": {
    "id": 123,
    "name": "string",
    "members": [
      {
        "id": 123,
        "name": "string",
        "email": "email@example.com",
        "phoneNumber": "string",
        "timeZone": "America/New_York",
        "language": {
          "locale": "en"
        }
      }
    ]
  }
}
```

#### Form Responses
```json
{
  "responses": {
    "name": {
      "label": "your_name",
      "value": "John Doe"
    },
    "email": {
      "label": "email_address",
      "value": "john@example.com"
    },
    "location": {
      "label": "location",
      "value": {
        "optionValue": "",
        "value": "inPerson"
      }
    },
    "notes": {
      "label": "additional_notes",
      "value": "string"
    },
    "guests": {
      "label": "additional_guests",
      "value": []
    }
  },
  "customInputs": {},                  // Custom form inputs
  "userFieldsResponses": {}            // User-defined field responses
}
```

#### Calendar Integration
```json
{
  "destinationCalendar": {
    "id": 123,
    "integration": "google_calendar",  // Calendar provider
    "externalId": "string",            // External calendar ID
    "userId": 123,
    "eventTypeId": 123,
    "credentialId": 123
  },
  "appsStatus": [
    {
      "appName": "Google Calendar",
      "type": "google_calendar",
      "success": 1,                   // Number of successful operations
      "failures": 0,                  // Number of failed operations
      "errors": [],                   // Error messages if any
      "warnings": []                  // Warning messages if any
    }
  ]
}
```

#### Additional Fields for Specific Events

**For BOOKING_RESCHEDULED:**
```json
{
  "rescheduleUid": "string",          // UID for rescheduling
  "rescheduleStartTime": "string",    // Original start time
  "rescheduleEndTime": "string",      // Original end time
  "rescheduledBy": "string"           // Who initiated the reschedule
}
```

**For BOOKING_CANCELLED:**
```json
{
  "cancellationReason": "string",     // Reason for cancellation
  "cancelledBy": "string"             // Who cancelled the booking
}
```

**For BOOKING_REJECTED:**
```json
{
  "rejectionReason": "string"         // Reason for rejection
}
```

**For BOOKING_PAID/BOOKING_PAYMENT_INITIATED:**
```json
{
  "paymentId": 123,
  "paymentData": {
    // Payment details object
  }
}
```

**For RECORDING_READY:**
```json
{
  "downloadLink": "string"            // Recording download URL
}
```

**For RECORDING_TRANSCRIPTION_GENERATED:**
```json
{
  "downloadLinks": {
    "transcription": {
      // Transcription access details
    },
    "recording": "string"             // Recording URL
  }
}
```

### Special Event Payloads

#### OOO_CREATED Event
```json
{
  "triggerEvent": "OOO_CREATED",
  "createdAt": "2023-05-24T09:30:00.538Z",
  "payload": {
    "oooEntry": {
      "id": 123,
      "start": "2023-05-25T00:00:00Z",
      "end": "2023-05-26T00:00:00Z",
      "createdAt": "string",
      "updatedAt": "string",
      "notes": "string",
      "reason": {
        "emoji": "🏖️",
        "reason": "Vacation"
      },
      "reasonId": 123,
      "user": {
        "id": 123,
        "name": "string",
        "username": "string",
        "timeZone": "America/New_York",
        "email": "email@example.com"
      },
      "toUser": {                    // Optional delegate
        "id": 123,
        "name": "string",
        "username": "string",
        "timeZone": "America/New_York",
        "email": "email@example.com"
      },
      "uuid": "string"
    }
  }
}
```

#### BOOKING_NO_SHOW_UPDATED Event
```json
{
  "triggerEvent": "BOOKING_NO_SHOW_UPDATED",
  "createdAt": "2023-05-24T09:30:00.538Z",
  "payload": {
    "message": "No-show status updated",
    "bookingUid": "string",
    "bookingId": 123,
    "attendees": [
      {
        "email": "email@example.com",
        "noShow": true
      }
    ]
  }
}
```

## Webhook Security

### Signature Verification

Cal.com signs all webhook payloads using HMAC-SHA256. To verify the authenticity:

1. **Header**: `X-Cal-Signature-256` contains the signature
2. **Algorithm**: HMAC-SHA256
3. **Verification Process**:

```javascript
const crypto = require('crypto');

function verifyWebhookSignature(secret, body, signature) {
  const expectedSignature = crypto
    .createHmac('sha256', secret)
    .update(body)
    .digest('hex');

  return expectedSignature === signature;
}

// In your webhook handler
app.post('/webhook', (req, res) => {
  const signature = req.headers['x-cal-signature-256'];
  const isValid = verifyWebhookSignature(
    YOUR_WEBHOOK_SECRET,
    JSON.stringify(req.body),
    signature
  );

  if (!isValid) {
    return res.status(401).send('Invalid signature');
  }

  // Process webhook...
});
```

## Implementation Notes

### Required Response
- Your endpoint should return a 2xx status code to acknowledge receipt
- Cal.com considers any non-2xx response as a failure

### Retry Policy
- Failed webhooks may be retried
- Implement idempotency using the `bookingId` or `uid` fields

### Content Type
- Default: `application/json`
- Custom templates can be configured for `application/x-www-form-urlencoded`

### Timezone Handling
- All timestamps are in UTC (ISO 8601 format)
- UTC offsets are calculated and added at runtime for organizer and attendees
- Use the provided timezone fields for local time calculations

### Platform-specific Fields
When using Cal.com Platform APIs, additional fields may be present:
- `platformClientId` - Platform client identifier
- `platformRescheduleUrl` - Platform-specific reschedule URL
- `platformCancelUrl` - Platform-specific cancel URL
- `platformBookingUrl` - Platform-specific booking URL

## Testing Webhooks

### Development Testing
1. Use tools like ngrok to expose your local endpoint
2. Configure webhook URL in Cal.com settings: `/settings/developer/webhooks`
3. Test with different event triggers

### Webhook Test Payload
You can use the "Test" button in Cal.com webhook settings to send a test payload.

## Example Implementation

### Node.js Express Handler
```javascript
const express = require('express');
const app = express();

app.post('/cal-webhook', express.json(), async (req, res) => {
  const { triggerEvent, createdAt, payload } = req.body;

  try {
    switch (triggerEvent) {
      case 'BOOKING_CREATED':
        await handleBookingCreated(payload);
        break;
      case 'BOOKING_CANCELLED':
        await handleBookingCancelled(payload);
        break;
      case 'BOOKING_RESCHEDULED':
        await handleBookingRescheduled(payload);
        break;
      // Handle other events...
    }

    res.status(200).json({ received: true });
  } catch (error) {
    console.error('Webhook processing error:', error);
    res.status(500).json({ error: 'Processing failed' });
  }
});

async function handleBookingCreated(payload) {
  // Sync with your system
  console.log('New booking:', {
    id: payload.bookingId,
    uid: payload.uid,
    title: payload.title,
    start: payload.startTime,
    end: payload.endTime,
    attendees: payload.attendees,
    organizer: payload.organizer
  });
}
```

## Important Considerations

1. **Idempotency**: Always handle duplicate webhooks gracefully using unique identifiers
2. **Async Processing**: Consider processing webhooks asynchronously for better performance
3. **Error Handling**: Implement proper error handling and logging
4. **Security**: Always verify webhook signatures in production
5. **Field Availability**: Not all fields are present in every webhook - implement null checks
6. **Meeting URLs**: Video meeting URLs are typically found in `payload.metadata.videoCallUrl`

## Support

For additional questions or issues:
- Check the official Cal.com documentation at https://cal.com/docs
- Review the webhook implementation in the Cal.com GitHub repository
- Contact Cal.com support for platform-specific questions