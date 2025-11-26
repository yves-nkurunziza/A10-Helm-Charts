```mermaid
graph TB
    subgraph "Kubernetes Cluster"
        subgraph "a10-tkc Operator"
            TKC[TKC Controller<br/>Deployment]
            SA[ServiceAccount]
            RBAC[ClusterRole /<br/>ClusterRoleBinding]
            Secret[Secret<br/>Thunder Credentials]
            PDB[PodDisruptionBudget]
            NP[NetworkPolicy]
            SVC[Service<br/>:8080 metrics]
        end
        
        subgraph "CRD Definitions"
            CRD1[HealthMonitor CRD]
            CRD2[ServiceGroup CRD]
            CRD3[VirtualServer CRD]
            CRD4[VirtualPort CRD]
        end
        
        subgraph "Application Config<br/>(a10-slb-config chart)"
            HM[HealthMonitor<br/>Instance]
            SG[ServiceGroup<br/>Instance]
            VS[VirtualServer<br/>Instance]
            VP[VirtualPort<br/>Instance]
            K8sSvc[Kubernetes<br/>Service]
        end
        
        subgraph "Monitoring"
            SM[ServiceMonitor]
            Prom[Prometheus]
        end
    end
    
    subgraph "External"
        Thunder[Thunder ADC<br/>Load Balancer]
        Client[External<br/>Clients]
    end
    
    %% Relationships
    TKC -->|uses| SA
    SA -->|bound to| RBAC
    TKC -->|reads| Secret
    TKC -->|watches| HM
    TKC -->|watches| SG
    TKC -->|watches| VS
    TKC -->|watches| VP
    SG -->|references| K8sSvc
    SG -->|uses| HM
    VP -->|references| VS
    VP -->|uses| SG
    TKC -->|configures| Thunder
    Thunder -->|routes traffic to| K8sSvc
    Client -->|connects to| Thunder
    SM -->|scrapes| SVC
    Prom -->|uses| SM
    NP -->|restricts| TKC
    PDB -->|protects| TKC
    
    %% Styling
    classDef operator fill:#e1f5ff,stroke:#01579b,stroke-width:2px
    classDef config fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef external fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef security fill:#ffebee,stroke:#b71c1c,stroke-width:2px
    
    class TKC,SA,RBAC,SVC operator
    class HM,SG,VS,VP,K8sSvc config
    class Thunder,Client external
    class Secret,PDB,NP security
```

## Architecture Overview

### Components

**TKC Operator (a10-tkc chart)**
- Watches CRD instances
- Reconciles state with Thunder ADC
- Runs with leader election
- Exports metrics on :8080

**Configuration Resources (a10-slb-config chart)**
- HealthMonitor: Health check configuration
- ServiceGroup: Backend pool + LB method
- VirtualServer: Frontend VIP
- VirtualPort: Port + protocol binding

**Security**
- NetworkPolicy: Egress only to Thunder + K8s API
- RBAC: Limited to specific resources
- PodSecurityContext: Non-root, read-only FS
- Secret: Thunder credentials (stringData)

### Traffic Flow

1. Client → Thunder ADC (VIP)
2. Thunder ADC → Kubernetes Service (NodePort/ClusterIP)
3. Service → Application Pods

### Control Flow

1. User deploys HealthMonitor, ServiceGroup, VirtualServer, VirtualPort CRDs
2. TKC watches for changes
3. TKC reconciles with Thunder ADC via AXAPI
4. Thunder ADC configures SLB objects
5. Status updated on CRD instances

### High Availability

- **TKC**: Leader election (only one active reconciler)
- **Thunder ADC**: Supports HA pairs (future enhancement)
- **PodDisruptionBudget**: Ensures availability during cluster operations
