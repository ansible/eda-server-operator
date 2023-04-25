# Create an AWX Access Token

To use EDA to launch automation jobs in AWX, you need create an access token in AWX.

### Create an AWX Access Token

Create an OAuth2 token for your user in the AWX UI.

1. Navigate to the Users page in the AWX UI
2. Select the username you wish to create a token for
3. Click on tokens, then the green plus icon
4. Application can be left empty, input a description and select the read/write scope.

> Alternatively, you can create one at the command-line using the `create_oauth2_token` manage command ([docs](https://docs.ansible.com/automation-controller/latest/html/administration/tower-manage.html#create-oauth2-token))
