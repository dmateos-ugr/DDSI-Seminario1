## ODBC
Esto es necesario independientemente de si usamos Zig, Python, C o C++. Es para instalar el driver manager y el driver para oracle. Es basicamente lo que nos dice [aquí](https://www.oracle.com/es/database/technologies/releasenote-odbc-ic.html).
1. Nos metemos [aquí](https://www.oracle.com/es/database/technologies/instant-client/linux-x86-64-downloads.html) y descargamos los archivos `oracle-instantclient-basic-21.4.0.0.0-1.el8.x86_64.rpm` y `oracle-instantclient-odbc-21.4.0.0.0-1.el8.x86_64.rpm`.
2. Nos metemos en la carpeta donde se hayan descargado.
3. Rezamos 3 ave marías.
4. Cerramos los ojos y ejecutamos:
```sh
sudo apt install unixodbc unixodbc-dev libaio1
sudo alien -i --scripts oracle-instantclient-basic-21.4.0.0.0-1.el8.x86_64.rpm
sudo alien -i --scripts oracle-instantclient-odbc-21.4.0.0.0-1.el8.x86_64.rpm
sudo touch /etc/odbcinst.ini
cd /usr/lib/oracle/21/client64/lib/
sudo ../bin/odbc_update_ini.sh /
```
5. Comprobamos que todo ha ido bien:
```sh
david@salero2:~$ odbcinst -q -d
[Oracle 21 ODBC driver]
```

## Zig
Esto sólo lo debería necesitar Miguel.
1. Ir a las [descargas de Zig](https://ziglang.org/download/) descargarse el archivo `zig-linux-x86_64-0.8.1.tar.xz`.
2. Extrarlo en algún sitio, por ejemplo en la carpeta personal, y renombrar la carpeta a `zig`.
3. Añadir la carpeta al PATH. Esto se puede hacer por ejemplo añadiendo la siguiente linea a tu archivo `~/.bashrc`:
```export PATH="$PATH:~/zig"```
4. Abrir una nueva terminal, o ejecutar el `.bashrc` en la actual con `source ~/.bashrc`, y ejecutar `zig version`, comprobando que pone 0.8.1.

## Mejorar el autocompletado de zig en VSCode
Asumiendo que instalamos zls en `/home/david/zls`:
1. Eliminar el `zls` si lo descargamos el otro día: `rm -rf ~/zls`
2. Descargar una nueva versión de [aquí](https://github.com/zigtools/zls/suites/4447978832/artifacts/118002110), y extraer el contenido de `x86_64-linux.tar.xz` en `~/zls`. Debe quedar algo así:
```sh
david@salero2:~/zls$ ls -R
.:
bin  README.md

./bin:
build_runner.zig  zls
```
3. Irse a la carpeta `~/zls/bin` y ejecutar `./zls config`. Ejemplo:
```
? Should this configuration be system-wide? (y/n) > n
Could not find 'zig' in PATH
? What is the path to the 'zig' executable you would like to use?/home/david/zig/zig
? Which code editor do you use? (select one)
> VSCode
? Do you want to enable snippets? (y/n) > n
? Do you want to enable style warnings? (y/n) > y
? Do you want to enable semantic highlighting? (y/n) > y
? Do you want to enable .* and .? completions? (y/n) > n
Writing config to /home/david/.config/zls.json ... successful.
```

4. Descargarse el archivo [build_runner.zig](https://raw.githubusercontent.com/zigtools/zls/584faec5de7f146b2335443a87a3c2b136bfa316/src/special/build_runner.zig) y guardarlo en `~/zls/bin/build_runner.zig`, reemplazando el existente. Se pude hacer abriéndolo con el navegador -> click derecho -> guardar como.
5. En VSCode, instalar las extensiones `tiehuis.zig` y `AugusteRame.zls-vscode`, si no estaban ya instaladas.
6. Irse a las Settings de VSCode (CTRL + ,), buscar `zigLanguageClient.path` y actualizarlo con la nueva path del binarios `zls`. En mi caso antes era `/home/david/zls/zls`, y ahora es `/home/david/zls/bin/zls`.
7. Reiniciar el VSCode.
8. Editar el archivo del repositorio `src/main.zig` y comprobar que nos autocompleta tanto escribiendo `std.` como `zdb.`.


También, desde la raíz del repositorio, ejecutad `zig build run` y comprobad que os compila y se os ejecuta (`zig build` compila en `./zig-out/bin/`, y el `run` lo ejecuta). Si no estáis conectados a la VPN de la UGR, a la hora de ejecutarlo os dará un error con una stack trace indicando que el error ocurrió en la línea que se intenta conectar a la base de datos.