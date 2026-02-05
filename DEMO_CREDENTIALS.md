# Demo Credentials for Testing

## Password Requirements

The API requires passwords with:

- At least 6 characters
- At least one uppercase letter (A-Z)
- At least one lowercase letter (a-z)
- At least one number (0-9)
- At least one special character (!@#$%^&\*)

## Test Account

You can use these credentials to test the login:

**Email:** `flutter@test.com`
**Password:** `Test123!`

Or create a new account with a password that meets the requirements above.

## Common Login Issues

1. **Weak Password**: Make sure your password includes all required character types
2. **Network Issues**: Ensure the API server is running on `http://localhost:4001`
3. **Invalid Email**: Use a valid email format

## API Endpoints

- Register: `POST /api/v1/auth/register`
- Login: `POST /api/v1/auth/login`
- Transactions: `GET/POST/DELETE /api/v1/transactions`
