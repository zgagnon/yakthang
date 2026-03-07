FROM yak-worker:latest

# Pre-seed Claude config so first-run onboarding wizard doesn't block sandboxed workers
USER yakshaver
RUN mkdir -p /home/yakshaver/.claude && echo '{"numStartups": 1}' > /home/yakshaver/.claude/.claude.json
USER root
