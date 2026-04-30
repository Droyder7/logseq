# Self-Hosting Logseq (Current Version)

This guide covers how to host Logseq yourself, including the frontend and the optional Sync/API backend (`db-sync`).

## Prerequisites

1.  **Frontend Build Tools**: 
    - Node.js (v18+) and `yarn`.
    - Clojure and `bb` (Babashka).
    - Java JDK 11+ (for Clojure/Shadow-CLJS).
2.  **Sync Backend (`db-sync`)**:
    - Node.js.
    - SQLite (for the Node adapter metadata/index).
    - (Optional) Cloudflare account if you want to deploy to Workers/D1.
3.  **Reverse Proxy**: Nginx or Caddy for HTTPS and routing.

---

## 1. Hosting the Web Frontend

The frontend is a static Single Page Application (SPA).

### Step A: Build the Frontend

1.  Clone the repository:
    ```bash
    git clone https://github.com/logseq/logseq.git
    cd logseq
    ```
2.  Install dependencies:
    ```bash
    yarn install
    ```
3.  Build for production:
    ```bash
    yarn release
    ```
    This will generate the static assets in the `./static` folder.

### Step B: Serve with Nginx

Point your web server to the `static` directory. 

Example Nginx config:
```nginx
server {
    listen 80;
    server_name yourdomain.com;

    root /path/to/logseq/static;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /static/js/ {
        # Optional: cache assets
        expires 1y;
        add_header Cache-Control "public";
    }
}
```

---

## 2. Hosting the Sync Backend (`db-sync`)

Logseq now uses `db-sync` for real-time collaboration and syncing. The code in `deps/db-sync` allows you to host your own sync relay, bypassing the official premium service.

### Step A: Build the Node Adapter

1.  Navigate to the db-sync directory:
    ```bash
    cd deps/db-sync
    ```
2.  Install dependencies:
    ```bash
    yarn install
    ```
3.  Build the Node.js adapter:
    ```bash
    yarn build:node-adapter
    ```
    The output will be at `worker/dist/node-adapter.js`.

### Step B: Configure and Run

Set the environment variables and run the adapter.

```bash
# Configuration
export DB_SYNC_PORT=8080
export DB_SYNC_BASE_URL="https://api.yourdomain.com"
export DB_SYNC_DATA_DIR="./data" # Where SQLite dbs and blobs will be stored
export DB_SYNC_LOG_LEVEL="info"

# Authentication (Cognito or compatible OIDC provider)
# db-sync uses JWT verification. Point these to your OIDC provider.
export COGNITO_ISSUER="your-issuer-url"
export COGNITO_CLIENT_ID="your-client-id"

node worker/dist/node-adapter.js
```

---

## 3. Connecting Apps to your Self-Hosted Service

You can connect both the Web frontend and the Desktop app to your custom sync server.

### Option 1: Via Settings UI
1.  Open Logseq.
2.  Go to **Settings** > **Sync**.
3.  Enter your **Custom Sync Server URL** (e.g., `https://api.yourdomain.com`).
4.  Restart/Reload the app.

### Option 2: Via Developer Console
If the UI option is restricted, you can manually set the server URL in the browser/app storage:
1.  Open Developer Tools (`Cmd+Opt+I` or `Ctrl+Shift+I`).
2.  In the **Console**, run:
    ```javascript
    localStorage.setItem('sync-server-url', 'https://api.yourdomain.com')
    ```
3.  Reload the app.

---

## Advanced: Overriding Asset Paths

If you need to serve assets from a different domain (CDN), you can modify `shadow-cljs.edn`:

```clojure
;; shadow-cljs.edn
:builds
 {:app {:output-dir "./static/js"
        :asset-path "https://cdn.yourdomain.com/static/js" ...}}
```

## Legacy Notes (PostgreSQL/backend.jar)
Previous versions of Logseq required a Clojure/JVM backend (`backend.jar`) and a PostgreSQL database. The current architecture (v0.10+) has shifted to a client-side SQLite (WASM) model with a lightweight `db-sync` relay. The legacy JVM requirements are now obsolete for self-hosting the latest version.
