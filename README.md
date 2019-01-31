Codefresh version of https://github.com/rouanw/build-window

See build instructions there.

# tl;dr

1. Rename either [config-github.ru](config-github.ru) or [config-noauth.ru](config-noauth.ru) to `config.ru`
2. Create `.env` file with content:
```
# For Github auth
GITHUB_KEY=<oauth app id>
GITHUB_SECRET=<oauth app secret>
GITHUB_ORG_ID=<orgs id>
# Codefresh
CODEFRESH_API_TOKEN=<top-right on https://g.codefresh.io/api/>
```
3. Configure [builds](config/builds.json)

note: `serviceName` is ~the name of the pipeline
4. Run `smashing start`
5. Open http://localhost:3030