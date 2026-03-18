c.JupyterHub.ip = '0.0.0.0'
c.JupyterHub.port = 8000
c.JupyterHub.authenticator_class = 'pam'
c.Authenticator.allowed_users = {'admin', 'analyst'}
c.Authenticator.admin_users = {'admin'}
# Shut down idle servers after 1 hour
c.ServerApp.shutdown_no_activity_timeout = 3600
