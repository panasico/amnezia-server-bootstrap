# amnezia-server-bootstrap

- [English](#english)
  - [Run](#run)
  - [What happens](#what-happens)
  - [If apt shows `Waiting for cache lock`](#if-apt-shows-waiting-for-cache-lock--unattended-upgr)
- [Русский](#русский)
  - [Запуск](#запуск)
  - [Что происходит](#что-происходит)
  - [Если apt пишет `Waiting for cache lock`](#если-apt-пишет-waiting-for-cache-lock--unattended-upgr)

## English

Prepares a fresh Ubuntu VM for installing AmneziaWG through the Amnezia client: an `amnezia` user with a key and sudo, a new SSH port, Fail2ban. Settings (port, Fail2ban exclusions) are at the top of `setup-vm.sh`.

### Run

```powershell
scp -r ../amnezia-server-bootstrap root@IP:/root/
ssh root@IP
```
```bash
bash /root/amnezia-server-bootstrap/setup-vm.sh        # port 2222 by default
```
or
```bash
bash /root/amnezia-server-bootstrap/setup-vm.sh 2345   # custom port
```

### What happens

1. System upgrade. On a fresh VM this can take a while — wait.
2. Creates the `amnezia` user, its key and passwordless sudo; the script checks key login itself.
3. **Pause 1.** The script prints the private key. Copy it (including the `BEGIN`/`END` lines) into the Amnezia client and a password manager, then type `y`.
4. Changes the SSH port, disables password login, installs Fail2ban.
5. **Pause 2.** Without closing the current session, connect as `amnezia` on the new port. If it works, type `yes` and the script removes the key from the server.
6. `sudo reboot`, then install AmneziaWG through the Amnezia client.

If the script stops with an error, run it again — it continues from where it stopped.

### If apt shows `Waiting for cache lock … (unattended-upgr)`

This is Ubuntu's automatic upgrade. Wait; if it takes too long:

```bash
kill -TERM <PID>     # PID from the apt message; the process finishes its current step and exits
dpkg --configure -a
bash /root/amnezia-server-bootstrap/setup-vm.sh
```

---

## Русский

Готовит новую Ubuntu VM к установке AmneziaWG через клиент Amnezia: пользователь `amnezia` с ключом и sudo, новый SSH-порт, Fail2ban. Параметры (порт, исключения Fail2ban) — в начале `setup-vm.sh`.

### Запуск

```powershell
scp -r ../amnezia-server-bootstrap root@IP:/root/
ssh root@IP
```
```bash
bash /root/amnezia-server-bootstrap/setup-vm.sh        # порт 2222 по умолчанию
```
или
```bash
bash /root/amnezia-server-bootstrap/setup-vm.sh 2345   # свой порт
```

### Что происходит

1. Обновление системы. На свежей VM может идти долго — ждём.
2. Создание пользователя `amnezia`, ключа и sudo без пароля; скрипт сам проверяет вход по ключу.
3. **Пауза 1.** Скрипт выводит закрытый ключ. Скопировать его (вместе со строками `BEGIN`/`END`) в клиент Amnezia и менеджер паролей, ввести `y`.
4. Смена SSH-порта, запрет входа по паролю, установка Fail2ban.
5. **Пауза 2.** Не закрывая текущую сессию, подключиться как `amnezia` на новом порту. Работает — ввести `yes`, скрипт удалит ключ с сервера.
6. `sudo reboot`, затем установка AmneziaWG через клиент Amnezia.

Если скрипт остановился с ошибкой — запустить его снова, он продолжит с места остановки.

### Если apt пишет `Waiting for cache lock … (unattended-upgr)`

Это автообновление Ubuntu. Подождать; если затянулось:

```bash
kill -TERM <PID>     # PID из сообщения apt; процесс доделает текущий шаг и выйдет
dpkg --configure -a
bash /root/amnezia-server-bootstrap/setup-vm.sh
```