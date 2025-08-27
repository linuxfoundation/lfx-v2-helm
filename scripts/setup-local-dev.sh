#!/bin/bash
# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to detect the local development environment
detect_environment() {
    if command -v minikube &> /dev/null && minikube status &> /dev/null; then
        echo "minikube"
    else
        echo "unknown"
    fi
}



# Function to setup certificates for Minikube
setup_minikube_certs() {
    print_status "Setting up certificates for Minikube..."
    
    # Check if mkcert is installed
    if ! command -v mkcert &> /dev/null; then
        print_error "mkcert is not installed. Please install it first:"
        echo "  macOS: brew install mkcert"
        echo "  Linux: https://github.com/FiloSottile/mkcert#installation"
        exit 1
    fi
    
    # Install mkcert CA
    mkcert -install
    
    # Create certificates directory
    mkdir -p certs/minikube
    
    # Generate wildcard certificate for lfx.local
    mkcert -key-file certs/minikube/_wildcard.key.pem -cert-file certs/minikube/_wildcard.cert.pem "*.lfx.local"
    
    # Create Kubernetes secret
    kubectl -n lfx create secret tls wildcard-lfx-local-cert \
        --key certs/minikube/_wildcard.key.pem \
        --cert certs/minikube/_wildcard.cert.pem \
        --dry-run=client -o yaml | kubectl apply -f -
    
    print_success "Minikube certificates created successfully"
}

# Function to setup environment-specific configuration
setup_environment_config() {
    local env=$1
    local values_file=""
    
    case $env in
        "minikube")
            values_file="minikube-values.yaml"
            setup_minikube_certs
            ;;
        *)
            print_error "Unknown environment: $env"
            exit 1
            ;;
    esac
    
    print_status "Using configuration from: $values_file"
    echo "To install the chart with this configuration, run:"
    echo "  helm install lfx-platform ./charts/lfx-platform -n lfx -f $values_file"
    echo ""
    echo "Or to upgrade an existing installation:"
    echo "  helm upgrade lfx-platform ./charts/lfx-platform -n lfx -f $values_file"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --environment ENV    Specify environment (minikube)"
    echo "  -c, --certs-only         Only setup certificates, don't show install commands"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                      # Auto-detect environment and setup"
    echo "  $0 -e minikube          # Setup for Minikube"
    echo "  $0 -c                   # Only setup certificates"
}

# Main script
main() {
    local environment=""
    local certs_only=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                environment="$2"
                shift 2
                ;;
            -c|--certs-only)
                certs_only=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Auto-detect environment if not specified
    if [[ -z "$environment" ]]; then
        print_status "Auto-detecting local development environment..."
        environment=$(detect_environment)
        
        if [[ "$environment" == "unknown" ]]; then
            print_error "Could not detect local development environment."
            echo "Please ensure Minikube is running, or specify with -e option."
            exit 1
        fi
        
        print_success "Detected environment: $environment"
    fi
    
    # Validate environment
    if [[ "$environment" != "minikube" ]]; then
        print_error "Invalid environment: $environment"
        echo "Valid options: minikube"
        exit 1
    fi
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if namespace exists
    if ! kubectl get namespace lfx &> /dev/null; then
        print_status "Creating lfx namespace..."
        kubectl create namespace lfx
    fi
    
    # Setup environment-specific configuration
    if [[ "$certs_only" == "true" ]]; then
        case $environment in
            "minikube")
                setup_minikube_certs
                ;;
        esac
    else
        setup_environment_config "$environment"
    fi
}

# Run main function with all arguments
main "$@" 