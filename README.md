📖 README – Time Bank Smart Contract

Overview

The Time Bank Smart Contract enables users to exchange time credits for services on-chain, fostering a decentralized time-based economy. It includes features for managing balances, service offers, escrow agreements, ratings, and transaction history.

✨ Features

Time Credits

Deposit, withdraw, and transfer time credits securely.

Logged transfers for transparent tracking.

User Profiles

Create personal profiles with names and skills.

Update skills and view ratings.

Service Marketplace

Offer services categorized by skill.

Toggle availability on demand.

Escrow Agreements

Create, complete, or cancel service-based escrows.

Automatic transfer of time credits upon completion.

Reputation System

Rate users from 1–5 after service completion.

Ratings are aggregated into a dynamic average score.

Transaction Logging

Every transfer and escrow action is recorded on-chain.

Includes metadata like type, description, and timestamp.

Admin Controls

Contract owner can transfer ownership.

Emergency freeze function for user accounts.

📚 Data Structures

time-balances: Stores time credits for each user.

user-profiles: Stores identity, skills, and ratings.

service-offers: Marketplace for skills/services.

escrow-agreements: Safe service contracts between provider and client.

transaction-history: Immutable log of activities.

⚙️ Key Functions

deposit-time, withdraw-time, transfer-time, transfer-time-logged

create-profile, update-skills

create-service-offer, toggle-service-availability

create-escrow, complete-escrow, cancel-escrow

rate-user

set-contract-owner, emergency-freeze-user

Multiple read-only getters for transparency.

🔒 Error Handling

Predefined error codes ensure predictable behavior:

ERR-INSUFFICIENT-BALANCE, ERR-INVALID-AMOUNT, ERR-SAME-PRINCIPAL

ERR-NOT-FOUND, ERR-UNAUTHORIZED, ERR-INVALID-STATUS

ERR-PROFILE-EXISTS, ERR-INVALID-RATING

✅ Usage Scenarios

Community time banks

Skill-sharing platforms

Decentralized marketplaces for freelancers

Mutual aid and volunteering systems