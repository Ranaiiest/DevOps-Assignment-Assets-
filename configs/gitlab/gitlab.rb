# /etc/gitlab/gitlab.rb (sanitized custom overrides on gitlab)

external_url 'https://gitlab.company.local'
letsencrypt['enable'] = false

nginx['redirect_http_to_https'] = true
nginx['ssl_certificate'] = "/etc/gitlab/ssl/gitlab.company.local.crt"
nginx['ssl_certificate_key'] = "/etc/gitlab/ssl/gitlab.company.local.key"

# 4 GB RAM tuning
puma['worker_processes'] = 2
sidekiq['concurrency'] = 10
