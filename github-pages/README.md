# GitHub Pages

The Actions build exports the Godot **Web** preset into `build/html/`:
`index.html`, `index.js`, `index.wasm`, `index.pck` and the generated images.
The `.nojekyll` marker in this directory is copied into that output.
Generated game files are build artifacts and are not committed to the repository.

On pushes to `main` (or a manual build of `main`), the workflow uploads this
HTML directory and deploys it using GitHub Pages. Pull requests and tags build
and attach `talk-on-html` without deploying the live site. Tag releases also
include the downloadable HTML build.

## Repository setup

In **Settings > Pages > Build and deployment**, select **GitHub Actions**.
A private source repository needs a GitHub plan that supports private-repository
Pages; the published game is publicly accessible. The source repository can
stay private.

## Local preview

With Godot 4.7.2 and its Web export templates installed, run from the repository root:

```sh
mkdir -p build/html
godot --headless --path . --import
godot --headless --path . --export-release Web build/html/index.html
python3 -m http.server 8000 --directory build/html
```

Open <http://localhost:8000/>. A web server is required; opening `index.html`
as a local file will not work. The export uses one thread and the Compatibility
renderer, so it does not require cross-origin isolation headers or a service worker.
Use a desktop keyboard and mouse. Click the game, then press Enter to start.
