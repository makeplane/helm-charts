# MinIO TLS Certificate Management

This directory contains the TLS certificates used for MinIO in airgapped deployments.

## Current Certificate Files

- **`s3.local.crt`** - Server certificate for MinIO
- **`s3.local.key`** - Private key for MinIO server
- **`mycorp-root.crt`** - Root CA certificate (used by clients to verify server certificates)
- **`s3-cert.conf`** - OpenSSL configuration file for certificate generation

## Certificate Details

The current certificate (`s3.local.crt`) includes the following Subject Alternative Names (SANs):
- `s3.local` - Primary hostname
- `plane-app-minio.thomas-airgap.svc.cluster.local` - Kubernetes service name
- `*.thomas-airgap.svc.cluster.local` - Wildcard for namespace services
- `localhost` - Local testing
- `127.0.0.1` - Local IP

## Generating New Certificates

### Prerequisites
- Access to the root CA private key (`mycorp-rootCA.key`)
- OpenSSL installed

### Step 1: Generate Private Key
```bash
cd charts/plane-enterprise/certs
openssl genrsa -out s3-new.local.key 2048
```

### Step 2: Create Certificate Signing Request (CSR)
```bash
openssl req -new -key s3-new.local.key -out s3-new.local.csr -config s3-cert.conf
```

### Step 3: Sign Certificate with Root CA
```bash
openssl x509 -req -in s3-new.local.csr \
  -CA mycorp-root.crt \
  -CAkey /path/to/mycorp-rootCA.key \
  -CAcreateserial \
  -out s3-new.local.crt \
  -days 365 \
  -extensions v3_req \
  -extfile s3-cert.conf
```

### Step 4: Verify Certificate
```bash
# Check Subject Alternative Names
openssl x509 -in s3-new.local.crt -text -noout | grep -A 5 "Subject Alternative Name"

# Verify certificate chain
openssl verify -CAfile mycorp-root.crt s3-new.local.crt
```

### Step 5: Replace Old Certificates
```bash
cp s3-new.local.crt s3.local.crt
cp s3-new.local.key s3.local.key
```

## Updating Certificate Configuration

If you need to add additional hostnames or IP addresses, edit the `s3-cert.conf` file:

```ini
[alt_names]
DNS.1 = s3.local
DNS.2 = plane-app-minio.thomas-airgap.svc.cluster.local
DNS.3 = *.thomas-airgap.svc.cluster.local
DNS.4 = localhost
DNS.5 = your-new-hostname.example.com  # Add new hostnames here
IP.1 = 127.0.0.1
IP.2 = 10.0.0.1  # Add new IP addresses here
```

## Deployment

After updating certificates:

1. **Redeploy MinIO**: The MinIO StatefulSet will automatically pick up the new certificates from the secret
2. **Redeploy API**: The API deployment will get the updated root CA certificate
3. **Verify**: Check that SSL connections work without hostname mismatch errors

```bash
# Restart MinIO
kubectl rollout restart statefulset/plane-app-minio-wl -n thomas-airgap

# Restart API
kubectl rollout restart deployment/plane-app-api-wl -n thomas-airgap
```

## Troubleshooting

### Common Issues

1. **"unable to get local issuer certificate"**
   - Root CA is not installed in client trust store
   - Check init container logs in API pod

2. **"hostname doesn't match"**
   - Certificate SAN doesn't include the hostname being accessed
   - Update `s3-cert.conf` and regenerate certificate

3. **"certificate verify failed"**
   - Certificate expired or invalid
   - Check certificate validity: `openssl x509 -in s3.local.crt -noout -dates`

### Verification Commands

```bash
# Check certificate expiration
openssl x509 -in s3.local.crt -noout -dates

# View certificate details
openssl x509 -in s3.local.crt -text -noout

# Test TLS connection
openssl s_client -connect s3.local:9000 -CAfile mycorp-root.crt

# Check if certificate is in Kubernetes secret
kubectl get secret plane-app-minio-tls -n thomas-airgap -o yaml
```

## Security Notes

- Keep private keys secure and never commit them to version control
- Use appropriate file permissions (600) for private keys
- Regularly rotate certificates before expiration
- Use strong encryption (RSA 2048+ or ECC P-256+)

## Certificate Lifecycle

- **Current Certificate Expiry**: Check with `openssl x509 -in s3.local.crt -noout -dates`
- **Recommended Renewal**: 30 days before expiration
- **Rotation Process**: Generate new certificates and redeploy services
