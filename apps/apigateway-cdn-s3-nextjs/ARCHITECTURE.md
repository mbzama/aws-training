# Architecture Diagram & Explanation

## Overall Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          AWS INFRASTRUCTURE                                  │
│                                                                              │
│  Region: us-east-1 (required for CloudFront certificate)                    │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                                                                      │  │
│  │  User Request to: https://app-dev.zamait.in                        │  │
│  │           │                                                         │  │
│  │           ▼                                                         │  │
│  │  ┌──────────────────────┐                                          │  │
│  │  │   Route53 DNS        │░░░░░░░░│ A Record Resolution    │  │
│  │  │  (DNS Resolution)    │░░░░░░░░▼                          │  │
│  │  │ app-dev.zamait.in    │     ┌──────────────────────┐     │  │
│  │  └──────────────────────┘     │ CloudFront           │     │  │
│  │                               │ Distribution         │     │  │
│  │                               │ d23aef3f.cloudfront  │     │  │
│  │                               │ .net                 │     │  │
│  │                               │                      │     │  │
│  │                               │ ✓ TLS/SSL            │     │  │
│  │                               │   Certificate:       │     │  │
│  │                               │   *.zamait.in (ACM)  │     │  │
│  │                               │                      │     │  │
│  │                               │ ✓ Compression:       │     │  │
│  │                               │   Gzip, Brotli      │     │  │
│  │                               │                      │     │  │
│  │                               │ ✓ Cache Policy       │     │  │
│  │                               │   HTML: 1 hour      │     │  │
│  │                               │   Assets: 24 hours  │     │  │
│  │                               │                      │     │  │
│  │                               │ ✓ Edge Locations    │     │  │
│  │                               │   Global Coverage   │     │  │
│  │                               └──────────┬──────────┘     │  │
│  │                                          │                │  │
│  │                              ┌───────────┼────────────┐   │  │
│  │                              │           │ (Origin    │   │  │
│  │                              │ Origin    │ Access     │   │  │
│  │                              │ Access    │ Control)   │   │  │
│  │                              │ Control   │            │   │  │
│  │                              ▼           ▼            │   │  │
│  │                         ┌─────────────────────────┐   │  │  │
│  │                         │   S3 Bucket             │   │  │  │
│  │                         │ (Private - Not Public)  │   │  │  │
│  │                         │ app-dev-us-east-1       │   │  │  │
│  │                         │                         │   │  │  │
│  │                         │ ✓ Versioning Enabled    │   │  │  │
│  │                         │ ✓ Encryption (AES256)   │   │  │  │
│  │                         │ ✓ Server Access Logs    │   │  │  │
│  │                         │ ✓ CORS Configured       │   │  │  │
│  │                         │                         │   │  │  │
│  │                         │ Contents:               │   │  │  │
│  │                         │ ├── index.html          │   │  │  │
│  │                         │ ├── 404.html            │   │  │  │
│  │                         │ ├── _next/              │   │  │  │
│  │                         │ │   ├── static/         │   │  │  │
│  │                         │ │   │   ├── *.js       │   │  │  │
│  │                         │ │   │   └── *.css      │   │  │  │
│  │                         │ │   └── data/          │   │  │  │
│  │                         │ ├── api/                │   │  │  │
│  │                         │ └── images/             │   │  │  │
│  │                         └─────────────────────────┘   │  │  │
│  │                                                      │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Request Flow

### 1. HTTP Request to HTTPS Redirect
```
User Browser
    │
    ├─ http://app-dev.zamait.in
    │         ▼
    └────► CloudFront
           (Redirect to HTTPS)
           ▼
    https://app-dev.zamait.in ◄─── ACM SSL Certificate
```

### 2. Static Asset Caching
```
First Request:
  ┌──────┐         ┌──────┐         ┌──────┐       ┌──────┐
  │User  │         │Edge  │         │CloudF│       │ S3   │
  │      │────────→│Loc   │────────→│ront  │──────→│      │
  │      │ static/ │ation │ MISS    │ cache│       │      │
  │      │.js      │      │         │ MISS │       │      │
  └──────┘         └──────┘         └──────┘       └──────┘
                                          ▲
                                          │
                                    File served
                              (TTL: 24 hours or 1 year)

             ▼ Cache stored at Edge Location ▼

Second Request (within TTL):
  ┌──────┐         ┌──────────────────────────────┐
  │User  │         │Edge Location                 │
  │      │────────→│(Cached from first request)   │
  │      │ static/ │                              │
  │      │.js      │ ✓ Faster response            │
  └──────┘         │ ✓ Reduced origin load        │
                   │ ✓ Reduced bandwidth cost     │
                   └──────────────────────────────┘
```

### 3. HTML Page Request (SPA Routing)
```
Request: /products/123
    ▼
CloudFront Function (viewer-request)
    ├─ Has file extension? → Allow through
    ├─ Is root (/)? → Allow through
    ├─ Is _next/api? → Allow through
    └─ (SPA route) → Rewrite to /index.html
    ▼
Request: /index.html
    ▼
S3 Bucket (GET index.html)
    ▼
Browser receives index.html
    ▼
React Router / Next.js Router handles /products/123 client-side
    ▼
Renders correct page
```

## Data Flow: Deployment Pipeline

```
┌─────────────────────────────────────────────────────────────┐
│                    LOCAL DEVELOPMENT                         │
│                                                             │
│  ┌──────────────────┐                                      │
│  │ Next.js App      │                                      │
│  │ - React         │                                      │
│  │ - Pages (app/)  │                                      │
│  │ - Styles        │                                      │
│  │ - Components    │                                      │
│  └────────┬─────────┘                                      │
│           │                                                │
│           ▼                                                │
│  ┌──────────────────┐        ┌────────────────────┐      │
│  │ npm run build    │───────→│ next/output export │      │
│  │ (Next.js Build)  │        │ Create static HTML │      │
│  └──────────────────┘        └─────────┬──────────┘      │
│                                        │                 │
│                                        ▼                 │
│                             ┌──────────────────┐         │
│                             │ ./out dir        │         │
│                             │ - Static HTML    │         │
│                             │ - _next/static   │         │
│                             │ - Assets         │         │
│                             └────────┬─────────┘         │
└──────────────────────────────────────┼─────────────────┘
                                       │
                                       │ (via deploy.sh or make deploy)
                                       │
         ┌─────────────────────────────┼─────────────────────────────┐
         │                             │                             │
         ▼                             ▼                             ▼
    ┌──────────┐              ┌────────────────┐            ┌──────────────┐
    │   AWS    │              │  S3 Bucket     │            │  CloudFront  │
    │   CLI    │─────────────→│ (Upload files) │───────────→│(Invalidate)  │
    └──────────┘              └────────────────┘            └──────────────┘
         │                            │                            │
         ▼                            ▼                            ▼
    AWS API                  Files stored                  Cache cleared
    Signature                 with TTL cache              ✓ Ready to serve
```

## Component Details

### CloudFront Distribution
```
┌─────────────────────────────────────┐
│      CloudFront Distribution        │
│                                     │
│  Behaviors:                         │
│  ├─ Default: All paths             │
│  │  ├─ Cache TTL: 3600s            │
│  │  ├─ Compress: Yes               │
│  │  ├─ Protocol: HTTPS             │
│  │  └─ Function: URL Rewrite       │
│  │                                 │
│  └─ /_next/*: Static assets        │
│     ├─ Cache TTL: 86400s           │
│     ├─ Compress: Yes               │
│     └─ Protocol: HTTPS             │
│                                     │
│  Viewer Certificate:                │
│  ├─ ACM: *.zamait.in               │
│  ├─ Protocol: TLSv1.2_2021         │
│  └─ Method: SNI                     │
└─────────────────────────────────────┘
```

### S3 Bucket Structure
```
app-dev-us-east-1/
│
├── index.html                    (cache: 1 hour)
├── 404.html                      (cache: 1 hour)
│
├── _next/
│   ├── static/
│   │   ├── chunks/
│   │   │   ├── app_layout.tsx-*.js       (cache: 1 year)
│   │   │   ├── app_page.tsx-*.js         (cache: 1 year)
│   │   │   └── ...
│   │   ├── css/
│   │   │   └── *.css                     (cache: 1 year)
│   │   └── media/
│   │       └── ...
│   └── data/
│       └── *.json                       (cache: 24 hours)
│
├── api/
│   └── *.json                           (cache: 24 hours)
│
└── images/
    └── *                                (cache: 24 hours)
```

### DNS Resolution Path
```
┌──────────────────┐
│  Client Browser  │
│  (resolver)      │
└────────┬─────────┘
         │
         │ Query: app-dev.zamait.in?
         ▼
    ┌─────────────────┐
    │  ISP DNS        │
    │  (recursive)    │
    └────────┬────────┘
             │
             │ No cache, query parent
             ▼
    ┌─────────────────┐
    │  Root Name      │
    │  Server         │
    └────────┬────────┘
             │
             │ Refer to .in servers
             ▼
    ┌─────────────────┐
    │  .in TLD        │
    │  Name Server    │
    └────────┬────────┘
             │
             │ Refer to zamait.in servers  
             ▼
    ┌──────────────────────────────┐
    │  Route53 Name Server         │
    │  (zamait.in hosted zone)     │
    │                              │
    │  Record:                     │
    │  app-dev.zamait.in CNAME     │
    │  [CloudFront domain]         │
    └────────┬─────────────────────┘
             │
             │ Response
             ▼
    ┌──────────────────────────────┐
    │  Client Browser              │
    │                              │
    │  Resolved to:                │
    │  d23aef3f.cloudfront.net     │
    └────────┬─────────────────────┘
             │
             │ Connect to CloudFront edge
             │ (nearest to user)
             ▼
    Content delivered from CloudFront
```

## TLS/SSL Certificate Chain

```
┌──────────────────────────┐
│   AWS Certificate        │
│   Manager (ACM)          │
│                          │
│  Domain: *.zamait.in    │
│  Region: us-east-1      │
│  Status: ISSUED         │
│  Type: Wildcard         │
│  Protocol: TLS 1.2+     │
└────────────┬─────────────┘
             │
             │ References
             ▼
    ┌──────────────────────────────┐
    │   CloudFront Distribution    │
    │                              │
    │   Viewer Certificate:        │
    │   ├─ ARN: [ACM Cert ARN]    │
    │   ├─ SSL Support: SNI Only  │
    │   ├─ Min Protocol: 1.2      │
    │   └─ Custom Domain:          │
    │       app-dev.zamait.in     │
    └──────────────────────────────┘
             │
             │ Used for
             ▼
    Client ←──── TLS Handshake ──→ CloudFront
    |            (HTTPS)          |
    |  Certificate chain verified   |
    |  Connection encrypted        |
    └──────────────────────────────┘
```

## Performance Optimization

### Caching Strategy
```
Request Path → Cache Handler → Decision → Action
    │              │               │
    ├─ *.js        └─ Hash name?  ─┬─ Yes → Cache 1 year
    │                             │         (immutable)
    ├─ *.css                      │
    ├─ *.woff                     │
    └─ *.jpg                      └─ No → Cache varies

    ├─ *.html     └─ Always check → Cache 1 hour
    ├─ *.json                        │
    └─ /          └─ Version tag?   ├─ Yes → Cache 24h
                                    └─ No → No cache

HTTP Headers:
  ├─ Cache-Control: public, max-age=31536000, immutable
  │  (for _next/* - JavaScript & CSS with content hash)
  │
  ├─ Cache-Control: public, max-age=3600
  │  (for HTML files - user-facing content)
  │
  └─ Cache-Control: public, max-age=86400
     (for other assets - images, etc.)
```

### Compression
```
CloudFront checks Accept-Encoding header:

Client sends:                CloudFront responds:
├─ gzip                  ────→ Gzipped response
├─ gzip, deflate             (if smaller)
├─ br (brotli)           ────→ Brotli response
│                             (if available & smaller)
└─ (none)               ────→ Uncompressed
                        
Typical compression:
├─ HTML: 70-80% reduction
├─ CSS: 75-85% reduction
├─ JavaScript: 70-80% reduction
└─ Images: No reduction (already compressed)
```

## Disaster Recovery

```
Version 1 (Current Live)
├─ S3 Object Version ID: abc123...
└─ CloudFront: Serving version 1
         │
         │ New deployment (Version 2)
         ▼
Version 2 (New Upload)
├─ S3 Object Version ID: def456...
├─ CloudFront: Invalidate cache
└─ CloudFront: Serve version 2
         │
         │ Issue detected
         │ (Rollback needed)
         ▼
Restore Version 1
├─ S3: Copy from version abc123
├─ Upload to S3
├─ CloudFront: Invalidate cache
└─ Live again: Version 1
```

## Monitoring & Logging

```
┌─────────────────────────┐
│   CloudWatch Metrics    │
│                         │
│   ├─ Requests          │
│   ├─ Data Downloaded   │
│   ├─ Data Uploaded     │
│   ├─ Error Rate        │
│   ├─ Cache Hit Ratio   │
│   └─ 4xx/5xx Errors    │
└────────────┬────────────┘
             │
    ┌────────┴─────────┐
    ▼                  ▼
Alarms          Dashboards
├─ High 4xx    ├─ Real-time
├─ Performance ├─ Historical
└─ Cost        └─ Trends
```

This architecture ensures:
- ✅ **Fast Delivery**: Global CDN edge locations
- ✅ **Security**: HTTPS/TLS encryption
- ✅ **Reliability**: S3 versioning & CloudFront failover
- ✅ **Cost Efficiency**: Aggressive caching strategy
- ✅ **Scalability**: Handles traffic spikes automatically
- ✅ **Simplicity**: Fully managed AWS services
