
In /etc/sudoers at the end of the file:
```
# Allow the specified users to use 'sudo' without a password
User_Alias PASSWORDLESS = rkopli
PASSWORDLESS ALL=(ALL)  NOPASSWD: ALL
```
