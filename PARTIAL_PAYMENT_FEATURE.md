# Partial Payment Feature Documentation

## Overview
The Partial Payment feature allows users to make partial settlements on individual transactions before the full amount is due. This feature includes dual-party OTP verification for security and maintains a complete payment history.

## Features

### 1. Partial Payment Processing
- **Dual OTP Verification**: Both lender and borrower must verify their email OTPs
- **Amount Validation**: Payment amount cannot exceed the remaining amount
- **Payment History**: Complete tracking of all partial payments
- **Automatic Settlement**: Transaction is automatically cleared when remaining amount reaches zero

### 2. Backend Components

#### Database Schema Changes (transaction.js)
```javascript
// New fields added to Transaction model
remainingAmount: {
  type: Number,
  default: function() {
    return this.amount; // Initialize with original amount
  }
},
totalAmountWithInterest: {
  type: Number,
  default: function() {
    return this.amount; // Will be calculated when interest is applied
  }
},
partialPayments: [{
  amount: {
    type: Number,
    required: true
  },
  paidBy: {
    type: String,
    required: true,
    enum: ['lender', 'borrower']
  },
  paidAt: {
    type: Date,
    default: Date.now
  },
  description: {
    type: String,
    default: ''
  }
}],
isPartiallyPaid: {
  type: Boolean,
  default: false
}
```

#### API Endpoints
1. **Send OTP for Partial Payment**
   - `POST /api/transactions/send-partial-payment-otp`
   - Body: `{ "email": "user@example.com" }`

2. **Verify OTP for Partial Payment**
   - `POST /api/transactions/verify-partial-payment-otp`
   - Body: `{ "email": "user@example.com", "otp": "123456" }`

3. **Process Partial Payment**
   - `POST /api/transactions/partial-payment`
   - Body: `{
     "transactionId": "uuid",
     "amount": 100,
     "description": "Optional description",
     "paidBy": "lender",
     "lenderEmail": "lender@example.com",
     "borrowerEmail": "borrower@example.com",
     "lenderOtpVerified": true,
     "borrowerOtpVerified": true
   }`

4. **Get Transaction Details**
   - `GET /api/transactions/:transactionId`
   - Returns complete transaction with partial payment history

#### Controller Functions (transactionController.js)
1. `sendPartialPaymentOTP()` - Sends OTP to specified email
2. `verifyPartialPaymentOTP()` - Verifies OTP for partial payment
3. `processPartialPayment()` - Processes the partial payment with dual verification
4. `getTransactionDetails()` - Retrieves transaction with payment history

### 3. Frontend Components

#### User Transactions Page (user_transactions_page.dart)
- **Partial Payment Button**: Appears on uncleared transactions
- **Payment History Display**: Shows all partial payments and remaining amount
- **Partial Payment Dialog**: Complete UI for making partial payments

#### Partial Payment Dialog Features
- Amount and description input fields
- Separate OTP sections for lender and borrower
- Real-time OTP sending and verification
- Payment processing with loading indicators
- Success/error feedback

### 4. Migration Script
- `addPartialPaymentFields.js` - Updates existing transactions with new fields
- Calculates total amount with interest for existing transactions
- Initializes remaining amount and payment history

## Usage Flow

### 1. Initiating Partial Payment
1. User clicks "Partial Payment" button on an uncleared transaction
2. Dialog opens with amount and description fields
3. Emails are auto-filled for both parties

### 2. OTP Verification Process
1. User clicks "Send OTP" for both lender and borrower
2. OTPs are sent to respective email addresses
3. Users enter OTPs and click "Verify OTP"
4. Both parties must verify before payment can proceed

### 3. Payment Processing
1. After dual OTP verification, "Process Payment" button becomes active
2. System validates payment amount against remaining amount
3. Payment is processed and transaction is updated
4. If remaining amount becomes zero, transaction is automatically cleared

### 4. Payment History
- All partial payments are stored with timestamps
- Remaining amount is updated after each payment
- Payment history is displayed in transaction cards

## Security Features

### 1. Dual Verification
- Both lender and borrower must verify their OTPs
- Prevents unauthorized partial payments
- Ensures both parties are aware of the payment

### 2. Amount Validation
- Payment amount cannot exceed remaining amount
- Prevents overpayment scenarios
- Maintains transaction integrity

### 3. Email Verification
- OTPs are sent to registered email addresses
- Ensures only authorized users can make payments
- Provides audit trail for all payments

## Technical Implementation

### 1. Interest Calculation
- Supports both simple and compound interest
- Calculates total amount with interest for partial payments
- Updates remaining amount based on current interest

### 2. Transaction States
- `isPartiallyPaid`: Boolean flag for partial payment status
- `remainingAmount`: Current outstanding amount
- `totalAmountWithInterest`: Total amount including interest
- `partialPayments`: Array of all partial payments

### 3. Error Handling
- Network error handling in frontend
- Validation errors for invalid amounts
- OTP verification error handling
- Transaction not found scenarios

## Database Migration

### Running the Migration
```bash
cd backend/src/migrations
node addPartialPaymentFields.js
```

### Migration Process
1. Connects to MongoDB database
2. Finds transactions without partial payment fields
3. Calculates total amount with interest for each transaction
4. Updates transactions with new fields
5. Initializes payment history as empty arrays

## Testing

### Backend Testing
1. Test OTP sending and verification
2. Test partial payment processing
3. Test amount validation
4. Test dual verification requirement
5. Test automatic transaction clearing

### Frontend Testing
1. Test partial payment dialog UI
2. Test OTP input and verification
3. Test payment processing flow
4. Test error handling and user feedback
5. Test payment history display

## Future Enhancements

### 1. Payment Scheduling
- Allow scheduling of future partial payments
- Automatic payment processing on scheduled dates

### 2. Payment Reminders
- Email reminders for upcoming partial payments
- Push notifications for payment due dates

### 3. Payment Analytics
- Track partial payment patterns
- Generate payment reports and insights

### 4. Multiple Currency Support
- Support for different currencies in partial payments
- Currency conversion for international transactions

## Troubleshooting

### Common Issues
1. **OTP Not Received**: Check email spam folder and email configuration
2. **Payment Failed**: Verify both OTPs are verified and amount is valid
3. **Transaction Not Found**: Ensure transaction ID is correct and user has access
4. **Network Errors**: Check internet connection and API endpoint availability

### Debug Information
- Check browser console for frontend errors
- Check server logs for backend errors
- Verify database connection and transaction data
- Confirm email service configuration

## API Response Examples

### Successful OTP Send
```json
{
  "message": "OTP sent successfully"
}
```

### Successful OTP Verification
```json
{
  "verified": true
}
```

### Successful Partial Payment
```json
{
  "success": true,
  "message": "Partial payment processed successfully",
  "remainingAmount": 500,
  "isFullyPaid": false
}
```

### Error Response
```json
{
  "error": "Both parties must verify their OTP"
}
``` 