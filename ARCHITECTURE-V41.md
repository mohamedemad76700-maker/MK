# MK School V41 Architecture

## Runtime
- `index.html`: HTML shell only.
- `assets/js/01-mk-school.js` through `06-mk-school.js`: ordered frontend modules extracted from the former monolith; execution order is preserved.
- `video_engine_backend/src/main.ts`: TypeScript/Express API, authentication, video queue, HLS authorization, platform state, and AI context.
- PostgreSQL: durable authentication, video access, jobs, course access, audit logs, points, and server-authoritative school state.
- Redis: health, rate limiting, and active session/device controls.
- Caddy: HTTPS termination and reverse proxy.

## Server-authoritative state
The admin publishes a sanitized snapshot to `platform_state`. Secrets and binary payloads are removed before persistence. Authenticated reads are filtered by role. The browser keeps only its local authentication/session UX and a synchronized cache; the server snapshot is the authoritative school-data source when the backend is connected.

## Video pipeline
1. Admin uploads a video.
2. Backend creates `video_jobs.job_id`.
3. FFmpeg converts the input to HLS.
4. Job status is stored in PostgreSQL.
5. Students receive a short-lived media token only after access and device checks.
6. PostgreSQL enforces the three-view limit transactionally.

## AI context
The backend AI loads the authorized platform snapshot from PostgreSQL and filters it by role before sending the school context to Groq. This prevents the model endpoint from relying solely on client-provided school data.
