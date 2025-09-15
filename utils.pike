protected void create (string name) {
	G->G->utils = this;
}

@"Some function currently working on":
__async__ void test() {
	werror("Hello: %O\n", "nothing yet");
}

@"Create a user with email and password":
__async__ void usercreate() {
	if (sizeof(G->G->args[Arg.REST]) < 2) {
		werror("Usage: pike app --exec=usercreate {email} {password}");
		return;
	}
	[string email, string pwd] = G->G->args[Arg.REST];
	werror("Creating user %O %O \n", email, pwd);
	await(G->G->DB->run_query(#"
		INSERT INTO users (email, password)
		VALUES (:email, :pwd)",
		(["email": email, "pwd": Crypto.Password.hash(pwd, "$2b$", 16384)]))); //bcrypt
}

@"Delete a user":
__async__ void userdelete() {
	[string email] = G->G->args[Arg.REST];
	werror("Deleting user\n");
	await(G->G->DB->run_query(#"
		DELETE FROM users
		WHERE email = :email",
		(["email": email])));
}

@"List all users":
__async__ void userlist() {
	werror("Listing users\n");
	mixed result = await(G->G->DB->run_query(#"
		SELECT email
		FROM users"));
	werror("Result: %O\n", result);
}

@"Find user by email":
__async__ void userfind() {
	[string email] = G->G->args[Arg.REST];
	werror("Finding user\n");
	mixed result = await(G->G->DB->run_query(#"
		SELECT email
		FROM users
		WHERE email = :email",
		(["email": email])));
	werror("Result: %O\n", result);
}

@"Create systemd service files":
void install() {
	Stdio.write_file("/etc/systemd/system/oren.service", sprintf(#"[Unit]
Description=Oren Calculator
Requires=oren.socket

[Service]
User=%s
ExecStart=%s app
WorkingDirectory=%s
ExecReload=kill -HUP $MAINPID
Restart=always
",
		getenv("SUDO_USER") || "root",
		String.trim(Process.run(({"which", master()->_pike_file_name}))->stdout),
		getcwd(),
	));
	Stdio.write_file("/etc/systemd/system/oren.socket", "[Socket]\nListenStream=443\n");
	Process.create_process(({"systemctl", "daemon-reload"}))->wait();
	Process.create_process(({"systemctl", "start", "oren"}))->wait();
	write("Service files created and service started.\n");
}

@"Update database schema":
__async__ void tables() {
	werror("Creating tables\n");
	await(G->G->DB->create_tables(0, 0));
}
@"This help information":
void help() {
	write("\nUSAGE: pike app --exec=ACTION\nwhere ACTION is one of the following:\n");
	array names = indices(this), annot = annotations(this);
	sort(names, annot);
	foreach (annot; int i; multiset|zero annot)
		foreach (annot || (<>); mixed anno;)
			if (stringp(anno)) write("%-20s: %s\n", names[i], anno);
}

__async__ void pokedb() {
	System.Timer tm = System.Timer();
	await(G->G->DB->run_query("select 1"));
	write("Null query took %.3fsec\n", tm->peek());
}

__async__ void hammerdb() {
	await(G->G->DB->run_query(({
		"drop table if exists hammer",
		"create table hammer (n int not null)",
		"insert into hammer values (0)",
	})));
	for (int lim = 10; lim <= 1000000; lim *= 10) {
		System.Timer tm = System.Timer();
		for (int i = 0; i < lim; ++i)
			await(G->G->DB->run_query("update hammer set n = n + 1"));
		float t = tm->peek();
		write("Performed %d transactions in %.3fs: %.3f tps\n", lim, t, lim / t);
	if (t > 2.0) break;
		}
}
