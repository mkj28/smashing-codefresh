Codefresh version of https://github.com/rouanw/build-window

See build instructions there.

## Example

![Screen shot of build window](https://github.com/mkj28/smashing-codefresh/blob/master/assets/images/sample_dashboard.png?raw=true 'Example build dashboard')

# tl;dr - local dev

1. Rename either [config-github.ru](config-github.ru) or [config-noauth.ru](config-noauth.ru) to `config.ru`
2. Create `.env` file with content:

```
# For Github auth
GITHUB_KEY=<oauth app id>
GITHUB_SECRET=<oauth app secret>
GITHUB_ORG_ID=<orgs id>
# Codefresh
CODEFRESH_API_TOKEN=<generated in https://g.codefresh.io/account-admin/account-conf/tokens>
# Slack - if you want to send slack notifications
SLACK_API_TOKEN=<Slack bot token>
# Redis - used for history, required for Slack
REDIS_URL=redis://localhost:6379
```

3. Configure [pipelines](config/pipelines.json):

   make sure `id`s are unique across **entire** file

   `service` is the pipeline id you can see in Codefresh pipeline page / General Settings / WEBHOOK

   You can use `branch_name` to filter to specific branches OR `branch_name_regex`

   If using `branch_name_regex` make sure to provide high enough `builds_to_fetch` number. Codefresh does not provide filtering by branch so we will fetch all builds and only then filter by branch regex provided.

4. Run `make start`
5. Open http://localhost:3030

# Deployment

[Heroku](https://github.com/Smashing/smashing/wiki/How-to%3A-Deploy-to-Heroku)

# Debugging in Visual Studio Code

1. Run `make debug`

2. Attach to rdebug-ide from VSCode

# Debugging widget data

See [Smashing wiki](https://github.com/Smashing/smashing/wiki/How-To%3A-Debug-incoming-widget-data)
