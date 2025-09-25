# Decentralized Fair Trade Certification Smart Contract

## Overview

This smart contract provides a decentralized system for managing fair trade certification of products. It enables producers to register products, submit certification applications, and maintain compliance records while allowing authorized certifiers to verify, approve, and audit products in a transparent and immutable manner.

## Features

- **Product Registration**: Producers can register their products with detailed information
- **Certification Management**: Complete lifecycle management of certifications including issuance, renewal, and expiration
- **Authorized Certifiers**: Role-based access control for certification authorities
- **Compliance Auditing**: Regular compliance checks with scoring and recommendations
- **Certification Renewal**: Streamlined renewal process with proper timing controls
- **Suspension/Reinstatement**: Emergency controls for certification status management
- **Verification System**: Public verification of certification authenticity

## Contract Structure

### Constants

#### Error Codes
- `ERR-UNAUTHORIZED-ACCESS (401)`: Unauthorized access attempt
- `ERR-PRODUCT-NOT-FOUND (404)`: Product does not exist
- `ERR-PRODUCT-ALREADY-EXISTS (409)`: Product already registered
- `ERR-CERTIFICATION-EXPIRED (410)`: Certification has expired
- `ERR-INVALID-PARAMETERS (400)`: Invalid input parameters
- `ERR-INSUFFICIENT-DOCUMENTATION (422)`: Missing or inadequate documentation
- `ERR-VERIFICATION-FAILED (423)`: Verification process failed
- `ERR-CERTIFIER-NOT-AUTHORIZED (403)`: Certifier lacks authorization
- `ERR-PRODUCT-NOT-CERTIFIED (424)`: Product lacks valid certification
- `ERR-RENEWAL-TOO-EARLY (425)`: Renewal requested outside valid window
- `ERR-INVALID-CERTIFICATION-LEVEL (426)`: Invalid certification level specified

#### Certification Status
- `CERTIFICATION-PENDING (0)`: Application submitted, awaiting review
- `CERTIFICATION-APPROVED (1)`: Certification approved and active
- `CERTIFICATION-REJECTED (2)`: Certification application rejected
- `CERTIFICATION-EXPIRED (3)`: Certification has expired
- `CERTIFICATION-SUSPENDED (4)`: Certification temporarily suspended

#### Certification Levels
- `LEVEL-BASIC (1)`: Basic fair trade certification
- `LEVEL-PREMIUM (2)`: Premium fair trade certification
- `LEVEL-GOLD (3)`: Gold standard fair trade certification

#### Time Constants
- `CERTIFICATION-VALIDITY-PERIOD`: 52,560 blocks (approximately 1 year)
- `RENEWAL-WINDOW`: 5,256 blocks (approximately 36 days before expiry)

### Data Structures

#### Products Map
Stores product information including producer details, product specifications, and timestamps.

#### Certifications Map
Maintains certification records with status, compliance scores, documentation hashes, and expiry information.

#### Authorized Certifiers Map
Registry of authorized certification bodies with accreditation details and active status.

#### Compliance Audits Map
Historical record of compliance audits with findings and recommendations.

#### Certification Renewals Map
Tracks renewal applications and their processing status.

## Public Functions

### Administrative Functions

#### `authorize-certifier`
```clarity
(authorize-certifier (certifier principal) (name string-ascii) (accreditation-id string-ascii))
```
Authorizes a new certifier. Only contract owner can execute.

**Parameters:**
- `certifier`: Principal address of the certifier
- `name`: Name of the certification body
- `accreditation-id`: Unique accreditation identifier

#### `deauthorize-certifier`
```clarity
(deauthorize-certifier (certifier principal))
```
Deactivates a certifier. Only contract owner can execute.

### Producer Functions

#### `register-product`
```clarity
(register-product (product-id string-ascii) (product-name string-ascii) (product-category string-ascii) (origin-country string-ascii))
```
Registers a new product for potential certification.

**Parameters:**
- `product-id`: Unique identifier for the product (max 64 characters)
- `product-name`: Name of the product (max 128 characters)
- `product-category`: Product category (max 64 characters)
- `origin-country`: Country of origin (max 32 characters)

#### `submit-certification-application`
```clarity
(submit-certification-application (product-id string-ascii) (certification-level uint) (documentation-hash string-ascii))
```
Submits an application for product certification.

**Parameters:**
- `product-id`: ID of registered product
- `certification-level`: Desired certification level (1-3)
- `documentation-hash`: Hash of supporting documentation

#### `request-certification-renewal`
```clarity
(request-certification-renewal (product-id string-ascii) (new-documentation-hash string-ascii))
```
Requests renewal of existing certification within the renewal window.

### Certifier Functions

#### `certify-product`
```clarity
(certify-product (product-id string-ascii) (approve bool) (compliance-score uint) (verification-notes string-ascii))
```
Reviews and approves/rejects certification applications.

**Parameters:**
- `product-id`: Product under review
- `approve`: Approval decision (true/false)
- `compliance-score`: Score from 0-100
- `verification-notes`: Additional notes (max 256 characters)

#### `conduct-compliance-audit`
```clarity
(conduct-compliance-audit (product-id string-ascii) (compliance-score uint) (findings string-ascii) (recommendations string-ascii))
```
Conducts compliance audit on certified products.

**Parameters:**
- `product-id`: Product being audited
- `compliance-score`: Updated compliance score (0-100)
- `findings`: Audit findings (max 512 characters)
- `recommendations`: Improvement recommendations (max 512 characters)

#### `process-certification-renewal`
```clarity
(process-certification-renewal (product-id string-ascii) (approve bool) (new-compliance-score uint))
```
Processes certification renewal requests.

#### `suspend-certification`
```clarity
(suspend-certification (product-id string-ascii))
```
Temporarily suspends an active certification.

#### `reinstate-certification`
```clarity
(reinstate-certification (product-id string-ascii))
```
Reinstates a suspended certification if not expired.

## Read-Only Functions

### Product Information
- `get-product`: Retrieve product details
- `get-certification`: Get certification information
- `is-product-certified`: Check current certification status
- `get-certification-expiry-info`: Get expiration details

### Certifier Information
- `get-certifier`: Retrieve certifier details

### Audit and Renewal Information
- `get-compliance-audit`: Get audit details by ID
- `get-certification-renewal`: Get renewal application status

### Verification
- `verify-certification-authenticity`: Verify certification with documentation hash

### Contract Statistics
- `get-contract-stats`: Get general contract information and statistics

## Usage Workflow

### 1. Setup Phase
1. Deploy the contract
2. Authorize certifiers using `authorize-certifier`

### 2. Product Registration
1. Producer calls `register-product` with product details
2. Producer submits certification application using `submit-certification-application`

### 3. Certification Process
1. Authorized certifier reviews application
2. Certifier calls `certify-product` to approve/reject
3. If approved, certification becomes active with expiry date

### 4. Ongoing Compliance
1. Certifiers conduct regular audits using `conduct-compliance-audit`
2. Compliance scores are updated based on audit results

### 5. Renewal Process
1. Producer requests renewal within renewal window using `request-certification-renewal`
2. Certifier processes renewal using `process-certification-renewal`
3. If approved, certification validity is extended

### 6. Emergency Actions
1. Certifiers can suspend certifications using `suspend-certification`
2. Suspended certifications can be reinstated using `reinstate-certification`

## Security Features

- **Role-based Access Control**: Only authorized certifiers can perform certification actions
- **Owner-only Administration**: Critical functions restricted to contract owner
- **Input Validation**: Comprehensive parameter validation for all functions
- **Expiry Management**: Automatic handling of certification expiration
- **Documentation Integrity**: Hash-based verification of supporting documents

## Time-based Controls

The contract uses block height for time-based operations:
- Certifications are valid for approximately 1 year (52,560 blocks)
- Renewal window opens 36 days before expiry (5,256 blocks)
- All timestamps are recorded as block heights for consistency

## Integration Notes

- All string parameters have specified maximum lengths
- Compliance scores are normalized to 0-100 scale
- Product IDs should be unique and meaningful for external systems
- Documentation hashes should use consistent hashing algorithms for verification

## Error Handling

The contract provides detailed error codes for different failure scenarios. Always check return values and handle errors appropriately in client applications.