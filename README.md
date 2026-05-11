# Canada Life Mortgage API

A Rails 8 JSON API for submitting and assessing mortgage applications.

---

## Requirements

- Ruby 3.3+
- Bundler

No additional system dependencies — SQLite is used for storage and is bundled.

---

## Setup

```bash
git clone <repo-url>
cd canada_life_mortgage_api

bundle
bin/rails db:prepare
```

---

## Running the Application

```bash
bin/rails s
```

The root URL redirects to the Swagger UI at `/api-docs`.

---

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/v1/mortgage_applications` | Submit a mortgage application |
| `GET`  | `/api/v1/mortgage_applications/:id` | Retrieve an application |
| `GET`  | `/api/v1/mortgage_applications/:id/assessment` | Run affordability assessment |

### Example: Create an application

```bash
curl -s -X POST http://localhost:3000/api/v1/mortgage_applications \
  -H "Content-Type: application/json" \
  -d '{
    "mortgage_application": {
      "annual_income": 75000,
      "monthly_expenses": 1500,
      "deposit_amount": 50000,
      "property_value": 300000,
      "term_years": 25
    }
  }'
```

### Example: Run assessment

```bash
curl -s http://localhost:3000/api/v1/mortgage_applications/1/assessment
```

**Assessment response:**

```json
{
  "loan_amount": 250000.0,
  "loan_to_value": 83.33,
  "debt_to_income_ratio": 24.0,
  "max_borrowing": 337500.0,
  "monthly_repayment": 1461.42,
  "decision": "approved",
  "explanation": "Application approved. Monthly repayment estimated at £1461.42 over 25 years at 5% fixed rate."
}
```

---

## Swagger UI

Interactive API docs are served at `/api-docs`.

Access is protected by HTTP Basic Auth. Default credentials (override via env vars):

```
SWAGGER_USERNAME=swagger
SWAGGER_PASSWORD=changeme
```

Copy `.env.example` and set real values before deploying.

---

## Running Tests

```bash
bin/rails test
```

The test suite covers:

- **Model validation** — presence, numericality, and two cross-field guards
- **Service calculations** — loan amount, LTV, DTI, max borrowing, decision logic, and explanation copy

---

## Running with Docker

```bash
docker build -t canada-life-mortgage-api .
docker run -p 3000:80 \
  -e RAILS_MASTER_KEY=$(cat config/master.key) \
  -e SWAGGER_USERNAME=swagger \
  -e SWAGGER_PASSWORD=changeme \
  canada-life-mortgage-api
```

---

## Design & Reflection

### Key Design Decisions

**1. Service object for affordability logic (`AffordabilityCalculator`)**

The assessment logic lives in a plain Ruby class rather than in the model or controller. This keeps the model focused on persistence concerns, the controller focused on HTTP concerns, and the calculation independently unit-testable without hitting the database. Memoisation via `||=` avoids redundant computation within a single call.

**2. API versioning from day one (`/api/v1/`)**

The routes are namespaced under `api/v1` at zero cost. If the assessment contract changes — new fields, altered thresholds — a `v2` can be introduced without breaking existing consumers. Versioning retrofitted later is significantly more disruptive.

**3. DB-level constraints alongside model validations**

The migration sets `null: false` and `precision: 15, scale: 2` on every column. Model validations are the first line of defence and provide user-facing error messages; the DB constraints are the last line — they enforce correctness even if code paths bypass ActiveRecord (console scripts, bulk imports, future jobs).

---

### System Evolution

**System boundaries**

The current monolith is the right starting point. As load or team size grows, the affordability engine is the natural extraction candidate — it's already isolated in a service object. It could become a dedicated microservice (or AWS Lambda) called over HTTP, with the Rails app delegating to it and caching results.

The application data store (SQLite → PostgreSQL) is the first infrastructure change needed before meaningful production traffic, giving connection pooling, concurrent writes, and point-in-time recovery.

**Handling increased load**

- Replace SQLite with PostgreSQL and add a read replica for GET-heavy traffic.
- Front the assessment endpoint with a cache (Redis + `Rails.cache`) keyed on application ID and a version token — affordability results for a given application are deterministic.
- Horizontal scaling behind a load balancer is straightforward because the service is stateless.

**Asynchronous processing**

Assessments are currently synchronous and fast. If the calculation became slow (external rate lookups, credit bureau calls), moving to a background job (Solid Queue is already in the Gemfile) would be natural: `POST /assessment` returns `202 Accepted` with a job ID, and the client polls `GET /assessment/:job_id` for the result.

---

### Operational Considerations

**Failure handling**

- All controller actions rescue `ActiveRecord::RecordNotFound` and return structured `404` JSON — consumers always get a parseable error body.
- Validation failures return `422` with a field-level errors hash so clients can surface precise messages.
- A global exception handler (`rescue_from StandardError`) should be added before production to prevent raw stack traces leaking.

**Monitoring and observability**

- Rails request logs include method, path, status, and duration out of the box. Structured JSON logging (Lograge) would make these ingestible by Datadog, Splunk, or CloudWatch.
- Add `Yabeda` or expose a `/metrics` endpoint for Prometheus: request rate, error rate, and assessment latency are the three metrics that matter most here.
- Distributed tracing (OpenTelemetry) would allow correlating an incoming request to its database queries and any downstream service calls.

**Data integrity and auditability**

- `timestamps` on every record gives a creation audit trail.
- For regulatory audit requirements, an append-only `mortgage_application_events` table (or PaperTrail) would capture state transitions: submitted → assessed → resubmitted.
- DB-level `null: false` constraints mean the data is always coherent regardless of how it arrives.

---

### Change & Flexibility

Affordability rules (LTV threshold, DTI threshold, income multiple, rate) are defined as constants in `AffordabilityCalculator`. Moving these to a database-backed `AffordabilityPolicy` model (with effective dates and an admin UI or CMS) would allow non-engineering teams to update them without a deployment. The service object interface stays the same — only the source of the constants changes. A simple approach is a `YAML` config file that operators can edit and deploy without a code change; a richer approach is a `Rule` table with a web UI backed by Active Admin.

---

### Trade-offs & Prioritisation

**Deliberately kept simple:**

- **Fixed rate (5%)** — a real implementation would fetch current rates from a market data API. Removed to keep the service self-contained and the test suite deterministic.
- **No authentication on the API itself** — HTTP Basic Auth secures Swagger UI; the API endpoints are open. Production would use API keys or OAuth tokens.
- **SQLite** — zero-config for development and CI; would be replaced by PostgreSQL before any meaningful traffic.
- **No background jobs** — assessments are synchronous. Solid Queue is already present for when this becomes necessary.

**If given 1–2 more weeks:**

1. **PostgreSQL + staging environment** — the biggest reliability risk right now.
2. **API authentication** — token-based auth (Bearer tokens) with a lightweight `ApiKey` model.
3. **Configurable affordability rules** — YAML-driven initially, then a DB-backed policy table if non-engineers need self-service.
4. **Structured logging + error alerting** — Lograge + Sentry, so issues surface before users report them.
