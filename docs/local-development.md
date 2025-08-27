# Local Development Setup

This document explains how to set up the LFX Platform for local development using either OrbStack or Minikube.

## Environment Differences

### OrbStack
- **Domain**: `k8s.orb.local`
- **HTTPS**: Automatic with built-in certificate management
- **DNS**: Automatic resolution for `*.k8s.orb.local` domains
- **Performance**: Generally faster than Minikube
- **Resource Usage**: More efficient resource utilization
- **Configuration**: Uses default `values.yaml`

### Minikube
- **Domain**: `lfx.local`
- **HTTPS**: Requires manual certificate setup with `mkcert`
- **DNS**: Multiple options available:
  - `minikube tunnel` (recommended)
  - Manual `/etc/hosts` entries using cluster IP
- **Performance**: Good for development but slower than OrbStack
- **Resource Usage**: Higher resource consumption
- **Configuration**: Uses `minikube-values.yaml`

## Quick Start

### Using the Setup Script

The easiest way to get started with Minikube is using the provided setup script:

```bash
# Make the script executable
chmod +x scripts/setup-local-dev.sh

# Auto-detect Minikube and setup
./scripts/setup-local-dev.sh

# Or specify environment explicitly
./scripts/setup-local-dev.sh -e minikube
```

### Manual Setup

#### OrbStack Setup

1. **Install OrbStack** (if not already installed):
   ```bash
   # macOS
   brew install orbstack
   ```

2. **Start OrbStack and create a cluster**:
   ```bash
   orb start
   ```

3. **Install the chart**:
   ```bash
   kubectl create namespace lfx
   helm install lfx-platform ./charts/lfx-platform -n lfx
   ```

4. **Access services**:
   - Authelia: https://auth.k8s.orb.local
   - Traefik Dashboard: http://traefik.k8s.orb.local:8080
   - Mailpit: https://mailpit.k8s.orb.local
   - LFX API: https://lfx-api.k8s.orb.local

#### Minikube Setup

1. **Install Minikube and mkcert** (if not already installed):
   ```bash
   # macOS
   brew install minikube mkcert
   
   # Linux
   # Follow instructions at https://minikube.sigs.k8s.io/docs/start/
   # and https://github.com/FiloSottile/mkcert#installation
   ```

2. **Start Minikube**:
   ```bash
   minikube start
   ```

3. **Setup certificates**:
   ```bash
   # Install mkcert CA
   mkcert -install
   
   # Generate certificates
   mkcert -key-file certs/minikube/_wildcard.key.pem -cert-file certs/minikube/_wildcard.cert.pem "*.lfx.local"
   
   # Create Kubernetes secret
   kubectl -n lfx create secret tls wildcard-lfx-local-cert \
       --key certs/minikube/_wildcard.key.pem \
       --cert certs/minikube/_wildcard.cert.pem
   ```

4. **Choose DNS resolution method**:

   **Option A: minikube tunnel (Recommended)**
   ```bash
   # Start minikube tunnel in a separate terminal
   minikube tunnel
   
   # Keep this running while using the cluster
   ```

   **Option B: Manual /etc/hosts setup**
   ```bash
   # Get the Traefik service cluster IP
   kubectl get svc lfx-platform-traefik -n lfx -o jsonpath='{.spec.clusterIP}'
   
   # Add to /etc/hosts (replace CLUSTER_IP with actual IP)
   echo "CLUSTER_IP lfx.local auth.lfx.local lfx-api.lfx.local" | sudo tee -a /etc/hosts
   ```

5. **Install the chart**:
   ```bash
   kubectl create namespace lfx
   helm install lfx-platform ./charts/lfx-platform -n lfx -f minikube-values.yaml
   ```

6. **Access services**:
   - Authelia: https://auth.lfx.local
   - Traefik Dashboard: http://traefik.lfx.local:8080
   - Mailpit: https://mailpit.lfx.local
   - LFX API: https://lfx-api.lfx.local

## Configuration Files

### `values.yaml` (default - OrbStack)
- Uses `k8s.orb.local` domain
- HTTP and HTTPS Traefik listeners (HTTPS handled by OrbStack)
- No certificate configuration needed
- Base configuration for OrbStack environments

### `minikube-values.yaml`
- Uses `lfx.local` domain
- HTTPS Traefik listeners with certificate references
- Manual certificate management required
- Overrides base configuration for Minikube environments

## Key Differences in Configuration

### Traefik Gateway Listeners

**OrbStack (values.yaml)**:
```yaml
traefik:
  gateway:
    listeners:
      web:
        port: 8000
        protocol: HTTP
      websecure:
        port: 8443
        protocol: HTTPS
        hostname: "*.k8s.orb.local"
      traefik:
        port: 8080
        protocol: HTTP
```

**Minikube (minikube-values.yaml)**:
```yaml
traefik:
  gateway:
    listeners:
      web:
        port: 8000
        protocol: HTTP
      websecure:
        port: 8443
        protocol: HTTPS
        hostname: "*.lfx.local"
        certificateRefs:
          - kind: Secret
            name: minikube-wildcard-cert
      traefik:
        port: 8080
        protocol: HTTP
```

### Authelia Configuration

**OrbStack (values.yaml)**:
```yaml
authelia:
  configMap:
    session:
      cookies:
        - domain: k8s.orb.local
          subdomain: auth
    identity_providers:
      oidc:
        clients:
          - audience: "https://lfx-api.k8s.orb.local"
```

**Minikube (minikube-values.yaml)**:
```yaml
authelia:
  configMap:
    session:
      cookies:
        - domain: lfx.local
          subdomain: auth
    identity_providers:
      oidc:
        clients:
          - audience: "https://lfx-api.lfx.local"
```

## Troubleshooting

### Common Issues

#### OrbStack
- **Services not accessible**: Ensure OrbStack is running and the cluster is active
- **DNS resolution**: OrbStack should handle this automatically
- **HTTPS errors**: OrbStack certificates should be trusted automatically

#### Minikube
- **Certificate errors**: Ensure `mkcert` is installed and certificates are generated
- **DNS resolution**: 
  - If using `minikube tunnel`: Ensure tunnel is running and not blocked by firewall
  - If using `/etc/hosts`: Verify cluster IP is correct and entries are properly formatted
- **HTTPS errors**: Verify certificates are properly installed in the system trust store
- **Tunnel issues**: Restart `minikube tunnel` if services become unreachable

### Debugging Commands

```bash
# Check cluster status
kubectl cluster-info

# Check namespace and resources
kubectl get all -n lfx

# Check Traefik logs
kubectl logs -n lfx -l app.kubernetes.io/name=traefik

# Check Authelia logs
kubectl logs -n lfx -l app.kubernetes.io/name=authelia

# Test DNS resolution
nslookup auth.k8s.orb.local  # OrbStack
nslookup auth.lfx.local      # Minikube

# Check certificate status
kubectl get secrets -n lfx

# Check Traefik service (for /etc/hosts setup)
kubectl get svc lfx-platform-traefik -n lfx -o jsonpath='{.spec.clusterIP}'

# Check minikube tunnel status
minikube tunnel --help
```

Get the list of OpenFGA Stores (output in debug mode)
```bash
kubectl run --rm -it fga-cli --image=openfga/cli --env="FGA_API_URL=http://lfx-platform-openfga.lfx:8080" --restart=Never -- --debug store list
```

## Best Practices

1. **Use the setup script**: It handles environment detection and configuration automatically
2. **Keep certificates organized**: Store them in the `certs/` directory with environment-specific subdirectories
3. **Use environment-specific values files**: Don't modify the base `values.yaml` for local development
4. **Document custom configurations**: If you need to modify configurations, document the changes
5. **Clean up resources**: Use `helm uninstall` and `kubectl delete namespace` when done

## Migration Between Environments

To switch between OrbStack and Minikube:

1. **Uninstall current deployment**:
   ```bash
   helm uninstall lfx-platform -n lfx
   ```

2. **Setup new environment**:
   ```bash
   ./scripts/setup-local-dev.sh -e minikube
   ```

3. **Install with new configuration**:
   ```bash
   # For OrbStack (uses default values.yaml)
   helm install lfx-platform ./charts/lfx-platform -n lfx
   
   # For Minikube (uses minikube-values.yaml)
   helm install lfx-platform ./charts/lfx-platform -n lfx -f minikube-values.yaml
   ```

## Development Workflow

1. **Start with OrbStack** (recommended for most developers)
   - Uses default `values.yaml` configuration
   - Automatic HTTPS and DNS resolution
   - Faster startup and better performance

2. **Use Minikube** if you need specific Kubernetes features or versions
   - Uses `minikube-values.yaml` configuration
   - Choose between `minikube tunnel` or manual `/etc/hosts` setup
   - More control over the environment

3. **Test both environments** before committing changes
4. **Update documentation** when adding new services or configurations

## DNS Resolution Options for Minikube

### Option 1: minikube tunnel (Recommended)
- **Pros**: Automatic, no manual configuration needed
- **Cons**: Requires keeping tunnel process running
- **Usage**: Run `minikube tunnel` in a separate terminal

### Option 2: Manual /etc/hosts setup
- **Pros**: No additional processes needed
- **Cons**: Manual configuration, IP changes require updates
- **Usage**: Add cluster IP to `/etc/hosts` file 
