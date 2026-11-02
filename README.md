# Problem 15 – Automating a Build with a Jenkins Pipeline

Every commit to this repository is built and tested automatically by Jenkins.
The pipeline lives in `Jenkinsfile` (declarative pipeline as code).

```
Commit ──► SCM poll (every minute) ──► Jenkins controller ──► agent-1 (label: python) ──► stage view + test report
```

## What is in the repo

| Path | Purpose |
| --- | --- |
| `Jenkinsfile` | Declarative pipeline: Checkout, Setup, Build, Test, Verify credentials; `post` publishes JUnit results |
| `app/calculator.py` | Small Python module that the pipeline builds |
| `tests/test_calculator.py` | pytest tests run in the Test stage |
| `jenkins/docker-compose.yml` | Jenkins controller + one agent |
| `jenkins/controller.Dockerfile` | Controller image with the needed plugins |
| `jenkins/agent.Dockerfile` | Agent image with Python 3 and Git |

## Run it (about 30 minutes)

Needs Docker Desktop and Git.

### 1. Push this repo to GitHub

```bash
cd jenkins-pipeline-demo
git init -b main
git add .
git commit -m "Add app, tests and Jenkinsfile"
git remote add origin https://github.com/<your-user>/jenkins-pipeline-demo.git
git push -u origin main
```

### 2. Start the Jenkins controller

```bash
cd jenkins
docker compose up -d --build jenkins
docker exec jenkins-controller cat /var/jenkins_home/secrets/initialAdminPassword
```

Open http://localhost:8080, paste the password, choose **Install suggested plugins**, create your admin user.

### 3. Add the agent (controller schedules, agent runs the stages)

1. Manage Jenkins → Nodes → **New Node** → name `agent-1`, Permanent Agent.
2. Remote root directory `/home/jenkins/agent`, Labels `python`, Usage "Only build jobs with label expressions matching this node".
3. Launch method: **Launch agent by connecting it to the controller**, tick **Use WebSocket**. Save.
4. Open the node page, copy the secret from the command shown, then:

```bash
cp .env.example .env        # paste the secret into AGENT_SECRET
docker compose up -d --build agent
```

5. Manage Jenkins → Nodes → **Built-In Node** → Configure → Number of executors `0`.
   Now only the agent can run builds.

### 4. Store credentials (never in the repo)

Manage Jenkins → Credentials → System → Global credentials → **Add Credentials**:

| Kind | ID | Used for |
| --- | --- | --- |
| Username with password (GitHub username + personal access token) | `github-creds` | Checking out the repo (needed if the repo is private) |
| Secret text (any demo value) | `app-api-token` | Used by the Verify credentials stage; masked as `****` in logs |

### 5. Create the pipeline job

New Item → name `jenkins-pipeline-demo` → **Pipeline** → OK.

- Build Triggers: tick **Poll SCM**, schedule `* * * * *`
- Pipeline → Definition: **Pipeline script from SCM**
- SCM: Git, Repository URL `https://github.com/<your-user>/jenkins-pipeline-demo.git`, Credentials `github-creds`
- Branch Specifier `*/main`, Script Path `Jenkinsfile`

Save, then click **Build Now** once (this registers the trigger from the Jenkinsfile).

### 6. Commit a change and watch it build automatically

```bash
echo "Build triggered by commit" >> CHANGES.md
git add CHANGES.md
git commit -m "Trigger build via SCM polling"
git push
```

Within a minute a new build starts on its own ("Started by an SCM change"). It should be green.

### 7. Controlled failure

Edit `tests/test_calculator.py` and change `assert add(2, 3) == 5` to `assert add(2, 3) == 6`, then:

```bash
git commit -am "Controlled failure: wrong expected value in test_add"
git push
```

The next build fails at the Test stage with `FAILED tests/test_calculator.py::test_add - assert 5 == 6`.
Revert it so the pipeline is green again:

```bash
git revert --no-edit HEAD
git push
```

## Webhook instead of polling (optional)

A GitHub webhook needs a public Jenkins URL (for example through ngrok).
Add the webhook `https://<public-url>/github-webhook/` in GitHub → Settings → Webhooks,
and replace `pollSCM('* * * * *')` with `githubPush()` in the Jenkinsfile.
