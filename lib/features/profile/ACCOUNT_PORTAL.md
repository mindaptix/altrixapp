# Account portal

The Me screen links to Insurance, Documents and Billing. Each link opens the
dedicated section in `AccountPortalScreen`; the main-shell chatbot remains behind
the pushed route.

The portal reads the existing patient profile through
`patientRepositoryProvider.getProfile()`. Optional `insurance`, `documents`
and `billing` sections are supported either in the profile payload or inside
its `client`, `patient` or `user` object. No additional API routes are assumed.

Supported optional sections:

```json
{
  "insurance": {
    "primary": {
      "carrier": "Carrier name",
      "memberId": "Member identifier",
      "groupNumber": "Group identifier",
      "copay": "$20",
      "deductible": "$500",
      "status": "active",
      "lastVerified": "2026-10-01"
    },
    "secondary": null
  },
  "documents": [
    {"type": "insurance_card", "name": "Card", "status": "received", "url": "/uploads/card.jpg"}
  ],
  "billing": {
    "balanceDue": 20,
    "nextCopay": 20,
    "paymentMethod": "Payment method description",
    "history": [
      {"description": "Visit", "date": "2026-10-01", "amount": 20, "status": "pending", "payer": "Payer"}
    ]
  }
}
```

Document slot types are `insurance_card`, `id_front` and `id_back`. The React
reference's flat insurance fields (`primaryCarrier`, `primaryMemberId`,
`primaryGroup`, etc.) are supported too. Missing balances are unknown, not zero.

Appointments and forms use the app's existing providers. Insurance changes,
document assistance and billing questions create actual clinic conversations;
confirmation appears only after the backend accepts the message.

Photo-library selection provides an in-memory preview with remove/replace
actions. Photos are not persisted or uploaded. A clinic document upload API
and a secure payment-provider integration are still needed for direct document
submission and in-app payments. The interface describes those limits without
simulating a successful upload or payment.
