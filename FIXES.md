Overview
This document describes every issue found across the codebase, why each one is a problem, how it was fixed, and what could go wrong if it was left unfixed.


FIX-01 - Wrong SERVICE_A_URL in docker-compose.yml

File:
docker-compose.yml

What was wrong:
SERVICE_A_URL was set to http://localhost:5000
SERVICE_A_URL=http://localhost:5000

Why it is a problem:
Inside a Docker container, localhost means the container itself, not other services. Service-b was trying to reach itself on port 5000, which had nothing running on it. This is the main reason the entire system failed to work.

How it was fixed:
Changed the URL to http://service-a:5000. Docker Compose creates an internal network where each service can be reached using its service name.
SERVICE_A_URL=http://service-a:5000

What could go wrong if left unfixed:
Service-b would never successfully connect to service-a. Every poll request would fail with a connection refused error.


>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

FIX-02 - Hardcoded secrets in service-a Dockerfile

File:
service-a/Dockerfile

What was wrong:
SECRET_KEY and DB_PASSWORD were hardcoded directly as ENV values inside the Dockerfile.
ENV SECRET_KEY=supersecret123
ENV DB_PASSWORD=admin1234

Why it is a problem:
Any secret written inside a Dockerfile gets stored permanently in the image layers. Anyone with access to the image can read these values by running docker history. They also get saved in git history and cannot be truly removed later.

How it was fixed:
Removed both ENV lines from the Dockerfile. Secrets are now passed at runtime using a .env file which is excluded from git.

What could go wrong if left unfixed:
Anyone who pulls the image or clones the repository can read the credentials directly.


>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

FIX-03 - Hardcoded secrets in docker-compose.yml

File:
docker-compose.yml

What was wrong:
DB_PASSWORD and SECRET_KEY were written in plain text inside docker-compose.yml.
- DB_PASSWORD=admin1234
- SECRET_KEY=supersecret123

Why it is a problem:
These values are committed to version control and visible to anyone who has access to the repository.

How it was fixed:
Replaced the hardcoded values with env_file pointing to a .env file. The .env file is listed in .gitignore so it never gets pushed to GitHub.
env_file:
  - .env

What could go wrong if left unfixed:
Credentials get leaked through git history, GitHub interface, or any repository clone.



>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

FIX-04 - Hardcoded Docker credentials in deploy.yml

File:
.github/workflows/deploy.yml

What was wrong:
Docker Hub username and password were written directly in the workflow file as plain text.
docker login -u myuser -p mypassword123

Why it is a problem:
Workflow files are committed to git. Anyone with repository access can read the credentials. They also appear in GitHub Actions logs.

How it was fixed:
Replaced with GitHub Actions secrets. Credentials are now stored securely in GitHub and referenced as environment variables.
echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin

What could go wrong if left unfixed:
Docker Hub account could be taken over. Attackers could push malicious images to the registry.




>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

FIX-05 - Hardcoded AWS credentials in terraform/main.tf

File:
terraform/main.tf

What was wrong:
AWS access key and secret key were written directly inside the Terraform provider block.
access_key = "AKIAIOSFODNN7EXAMPLE"
secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"

Why it is a problem:
AWS credentials committed to source code end up in git history permanently. AWS and attackers both scan public repositories for exposed keys. This can result in full account compromise and large unexpected bills within minutes of exposure.

How it was fixed:
Removed both credentials from the provider block entirely. AWS credentials should be provided through environment variables or an IAM instance role, never in code.

What could go wrong if left unfixed:
Complete AWS account takeover, data breach, and large unauthorized charges.


>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

FIX-06 - Security group opens all ports to the internet

File:
terraform/main.tf

What was wrong:
The security group allowed inbound traffic on all TCP ports from 0 to 65535 from any IP address.
from_port = 0
to_port   = 65535
cidr_blocks = ["0.0.0.0/0"]

Why it is a problem:
Every port on the server is exposed to the entire internet. Anyone can attempt connections to any service running on the instance.

How it was fixed:
Restricted inbound traffic to port 5000 for the application and port 22 for SSH from a known admin IP only. Outbound traffic restricted to ports 80 and 443.

What could go wrong if left unfixed:
Server compromise, brute force attacks, and unauthorized access to internal services.


>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

FIX-07 - USER root in both Dockerfiles

File:
service-a/Dockerfile, service-b/Dockerfile

What was wrong:
Both Dockerfiles explicitly set USER root, meaning the application runs as the root user inside the container.
USER root

Why it is a problem:
If the container is compromised, the attacker gets root level access. This goes against the principle of least privilege and is a well known Docker security mistake.

How it was fixed:
Created a dedicated non-root user in each Dockerfile and switched to that user before running the application.
RUN useradd -m appuser
USER appuser

What could go wrong if left unfixed:
A container escape attack could give an attacker root access to the underlying host machine.



>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

FIX-08 - SSH as root with host key checking disabled

File:
.github/workflows/deploy.yml

What was wrong:
The deploy step connected via SSH as root to a hardcoded IP, with StrictHostKeyChecking disabled.
ssh -o StrictHostKeyChecking=no root@203.0.113.45

Why it is a problem:
Connecting as root gives an attacker full server control if the key is ever compromised. Disabling host key checking removes protection against man-in-the-middle attacks.

How it was fixed:
Deploy user, host IP, SSH key, and known hosts are now all stored as GitHub secrets. The connection verifies the server identity before connecting.

What could go wrong if left unfixed:
Full server compromise and traffic interception during deployments.



>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
FIX-09 - No resource limits in Kubernetes deployment

File:
k8s/deployment.yaml

What was wrong:
Only resource requests were defined. No limits were set.

Why it is a problem:
Without limits a single pod can consume all available CPU and memory on a node. This causes other workloads on the same node to be evicted or crash.

How it was fixed:
Added memory and CPU limits alongside the existing requests for both services.
limits:
  memory: "128Mi"
  cpu: "200m"

What could go wrong if left unfixed:
Node instability and cascading failures affecting unrelated workloads.

>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

FIX-10 - No liveness or readiness probes

File:
k8s/deployment.yaml

What was wrong:
No health probes were defined for any container.

Why it is a problem:
Without probes, Kubernetes has no way to detect if the application is running correctly. Traffic gets routed to broken pods and crashed containers are not restarted.

How it was fixed:
Added liveness and readiness probes pointing to the existing /health endpoint on port 5000.
livenessProbe:
  httpGet:
    path: /health
    port: 5000

What could go wrong if left unfixed:
Users receive errors from unhealthy pods. Failed pods remain in rotation indefinitely.

>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>


FIX-11 - Using latest image tag in Kubernetes deployment

File:
k8s/deployment.yaml

What was wrong:
The container image was referenced as myorg/devops-app:latest.
image: myorg/devops-app:latest

Why it is a problem:
The latest tag always points to the most recently pushed image. This makes deployments unpredictable and makes it impossible to roll back to a specific known version.

How it was fixed:
Changed to a fixed version tag 1.0.0. In the CI pipeline, images are also tagged with the git commit SHA for full traceability.
image: myorg/devops-app:1.0.0

What could go wrong if left unfixed:
No rollback capability. Different pod replicas could be running different versions of the code.


>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>


FIX-12 - depends_on does not wait for service readiness

File:
docker-compose.yml

What was wrong:
depends_on was configured with just the service name and no condition.
depends_on:
  - service-a

Why it is a problem:
This only waits for the container to start, not for the application inside it to be ready. Service-b could start polling service-a before Flask had finished starting up.

How it was fixed:
Added a healthcheck to service-a that checks the /health endpoint. Changed depends_on to use condition: service_healthy.
depends_on:
  service-a:
    condition: service_healthy

What could go wrong if left unfixed:
Service-b fails on its first poll attempt every time the stack starts up.




>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

FIX-13 - Large base images in both Dockerfiles

File:
service-a/Dockerfile, service-b/Dockerfile

What was wrong:
Full python:3.11 and node:18 base images were used, each around 1GB in size.
FROM python:3.11
FROM node:18

Why it is a problem:
Large images take longer to build, pull, and deploy. They also have a larger attack surface with more unnecessary packages included.

How it was fixed:
Switched to python:3.11-slim and node:18-alpine, reducing image sizes to around 150MB and 180MB respectively. That is roughly a 75 percent reduction.
FROM python:3.11-slim
FROM node:18-alpine

What could go wrong if left unfixed:
Slower CI/CD pipelines, larger storage costs, and unnecessary security exposure.


>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>


FIX-14 - Incorrect Docker layer caching in both Dockerfiles

File:
service-a/Dockerfile, service-b/Dockerfile

What was wrong:
The entire codebase was copied before installing dependencies.
COPY . .
RUN pip install -r requirements.txt

Why it is a problem:
This meant Docker had to reinstall all packages every time any file changed, even if dependencies were unchanged. Builds were unnecessarily slow.

How it was fixed:
Dependency files are copied first, packages are installed, then the rest of the code is copied. Docker now only reinstalls packages when the dependency file actually changes.
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .

What could go wrong if left unfixed:
Every code change triggers a full dependency reinstall, significantly slowing down builds.


>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>


FIX-15 - No graceful shutdown in worker.js

File:
service-b/worker.js

What was wrong:
No handlers for SIGTERM or SIGINT signals were present.

Why it is a problem:
When Docker or Kubernetes stops a container, it sends SIGTERM first. Without a handler the process gets killed abruptly, potentially losing in-flight requests.

How it was fixed:
Added process.on handlers for both SIGTERM and SIGINT that log the shutdown event and exit cleanly.
process.on('SIGTERM', () => {
  process.exit(0);
});

What could go wrong if left unfixed:
Abrupt kills during Docker stop or Kubernetes pod termination, potential in-flight request loss.


>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>


FIX-16 - Worker polls immediately before service-a is ready

File:
service-b/worker.js

What was wrong:
The first poll to service-a happened immediately when the worker started, before service-a was ready.
pollServiceA();
setInterval(pollServiceA, INTERVAL_MS);

Why it is a problem:
Even with depends_on, service-a may still be starting up when service-b first polls. This causes an unnecessary error on every startup.

How it was fixed:
Added a 5 second startup delay using setTimeout before the first poll runs.
setTimeout(() => {
  pollServiceA();
  setInterval(pollServiceA, INTERVAL_MS);
}, 5000);

What could go wrong if left unfixed:
Guaranteed error on first startup poll, noisy logs, and misleading error alerts.


>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>


FIX-17 - No logging in app.py

File:
service-a/app.py

What was wrong:
No logging was configured in the Flask application.

Why it is a problem:
Without logging there is no way to see what requests are being made or what errors are occurring. Debugging any issue in production would be extremely difficult.

How it was fixed:
Added structured logging to stdout using Python's logging module, including timestamps and log levels on every route.

What could go wrong if left unfixed:
Zero observability. Issues in production would be nearly impossible to diagnose.


>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>


FIX-18 - No secret validation at startup

File:
service-a/app.py

What was wrong:
The application would start silently even if SECRET_KEY was missing or set to the insecure default.
SECRET_KEY = os.environ.get("SECRET_KEY", "supersecret123")

Why it is a problem:
The app running with a known default secret key in production is a security risk. There is no warning or failure to alert the operator.

How it was fixed:
The application now exits at startup if SECRET_KEY is not set, and logs a warning if the default insecure value is detected.

What could go wrong if left unfixed:
Application runs insecurely in production with no indication that the configuration is wrong.


>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>


FIX-19 - No namespace in Kubernetes manifests

File:
k8s/deployment.yaml

What was wrong:
No namespace was specified, so all resources were deployed to the default namespace.

Why it is a problem:
Deploying to the default namespace mixes application workloads with system resources and makes access control and resource isolation impossible.

How it was fixed:
Added namespace: devops-app to all Kubernetes resources.
namespace: devops-app

What could go wrong if left unfixed:
Poor resource isolation, difficult access control, and risk of interfering with other workloads.


>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>


FIX-20 - service-b had no Kubernetes manifests

File:
k8s/deployment.yaml

What was wrong:
Only service-a had a Kubernetes Deployment defined. service-b had no manifests at all.

Why it is a problem:
Without a Deployment manifest, service-b cannot be deployed to Kubernetes. The worker would simply not exist in the cluster.

How it was fixed:
Added a complete Deployment manifest for service-b including resource requests, limits, and the SERVICE_A_URL environment variable.

What could go wrong if left unfixed:
service-b cannot be deployed to Kubernetes at all.

>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>


FIX-21 - No test stage in CI pipeline

File:
.github/workflows/deploy.yml

What was wrong:
The pipeline went directly from code push to build to deploy with no testing in between.

Why it is a problem:
Any broken code would immediately be built and deployed to production without any checks. A simple syntax error or broken function would reach users.

How it was fixed:
Added a test job that runs before the build job. The build and deploy steps only proceed if tests pass.

What could go wrong if left unfixed:
Broken code ships to production on every push.


>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

FIX-22 - No image versioning in CI pipeline

File:
.github/workflows/deploy.yml

What was wrong:
Only the latest tag was pushed on every build.
docker build -t myorg/devops-app:latest ./service-a

Why it is a problem:
There is no way to identify which commit produced which image. Rolling back to a previous version is impossible.

How it was fixed:
Images are now tagged with both latest and the git commit SHA, making every build fully traceable and rollbacks possible.
docker build -t myorg/devops-app:${{ github.sha }} ./service-a

What could go wrong if left unfixed:
No rollback capability and no traceability between deployed images and source code commits.



>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>


Self-Initiated Improvements

1.Added .dockerignore for both services


Why:
Without a .dockerignore file, the COPY command pulls everything into the image including node_modules, the .git folder, .env files, and other files that should never be inside a container. Added .dockerignore to both service-a and service-b to exclude these files and keep images clean and small.
Files added:
  - service-a/.dockerignore
  - service-b/.dockerignore

2.Added restart policy in docker-compose

Why:
Without a restart policy, if either service crashes it stays down until someone manually restarts it. Added restart: unless-stopped to both services so the system recovers automatically from failures.

3.Switched to gunicorn for service-a

Why:
The original CMD used python app.py which runs Flask's built-in development server. This server is single-threaded and not suitable for production use. Gunicorn was already listed in requirements.txt but was never being used. Updated the CMD to run gunicorn with 2 workers instead.


4.Added structured logging to service-a

Why:
Without any logging there is no visibility into what the service is doing. Added request logging on all routes and startup validation messages so any issues are immediately visible in Docker logs and Kubernetes log streams.


