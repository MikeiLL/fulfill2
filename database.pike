inherit annotated;
#pragma no_experimental_warnings

//If defined, all queries that take longer than this will be reported to the console
#define SLOW_QUERY_THRESHOLD 0.25

Sql.Sql conn;
Concurrent.Promise query_pending;
mapping | zero profile;
System.Timer profile_timer;

constant tables = ([
	"producers": ({
		"id serial primary key",
		"company varchar",
		"email varchar unique",
		"phone varchar unique",
		"web varchar",
	  //"add CONSTRAINT at_least_one_contact_point CHECK (COALESCE((email != '') OR (phone != '') OR (web != ''), FALSE))",
	}),
	"users": ({
		"id serial primary key",
		"email varchar not null unique",
		"displayname varchar not null",
		"user_level int not null default 1", //-- noaccess=0, manager=1, admin=3
		"password varchar not null default ''",
	}),
	"products": ({
		"id serial primary key",
		"name varchar",
		"producer_id int references producers",
		"options_id int references options",

	}),
	"options": ({
		"id serial primary key",
		"name varchar",
		"config jsonb",

	}),
	"stock": ({
		"id serial primary key",
		"count smallint",
		"product_id int references products",
		"option_id int references options",

	}),
	"fulfillments": ({
		"id serial primary key",
		"received timestamptz not null default now()",
		"provider varchar",
		"fulfilled timestamptz",
		"orderdetails jsonb not null",
		"materials jsonb not null",
		"services jsonb not null",

	}),
	"services": ({
		"id serial primary key",
		"name varchar not null",
		"description varchar",
		"cost smallint not null default 0",
		"unit varchar not null default 'hr'",// -- eg hr, piece, box, case"
		"enabled boolean not null default true",
  }),
]);

/**
	@param sql may be an array which includes queries and callbacks.
	eg:

	({"select id, seq where blah blah",
	callback_to_figure_out_changes,
	"update set seq = :cur where id=:other"
	"update set seq = :new where id = :this"
	})
*/
__async__ array(mapping) run_query(string|array sql, mapping|void bindings) {

	// TODO: figure out why promise queries are failing with broken promise error
	//write("Query result: %O\n", await(mysqlconn->promise_query(query))->get());
	//write("%O\n", await(Protocols.HTTP.Promise.do_method("GET", "http://localhost:8002/")));
	//write("Query result: %O\n", mysqlconn->typed_query(query));
	//write("%O\n", mysqlconn->promise_query);
	//write("Waiting for query: %O\n", query[..64]);

	// If sql is an array will perform them in a transaction
	// eg: a process sequence change: 1,2,3,4: 1,2,4,3
	// Currently only support in/decremental updates


	object pending = query_pending;
	object completion = query_pending = Concurrent.Promise();

	if (pending) await(pending->future()); //If there's a queue, put us at the end of it.

	#ifdef SLOW_QUERY_THRESHOLD
		System.Timer tm = System.Timer();
	#endif

	mixed ret, ex;
	if (arrayp(sql)) {
		ret = ({ });
		ex = catch {await(conn->promise_query("begin"))->get();};
		if (!ex) foreach (sql, string|function q) {
			//A null entry in the array of queries is ignored, and will not have a null return value to correspond.
			if (ex = q && catch {
				if (functionp(q)) ((function)q)(ret, bindings); //q is allowed to mutate its bindings.
				else {
					ret += ({await(conn->promise_query(q, bindings))->get()});
					if (profile) {
						profile[q]++;
					}
				}
			}) break;
		}
		//Ignore errors from rolling back - the exception that gets raised will have come from
		//the actual query (or possibly the BEGIN), not from rolling back.
		if (ex) catch {await(conn->promise_query("rollback"))->get();};
		//But for committing, things get trickier. Technically an exception here leaves the
		//transaction in an uncertain state, but I'm going to just raise the error. It is
		//possible that the transaction DID complete, but we can't be sure.
		else ex = catch {await(conn->promise_query("commit"))->get();};
	}
	else {
		//Implicit transaction is fine here; this is also suitable for transactionless
		//queries (of which there are VERY few).
		ex = catch {ret = await(conn->promise_query(sql, bindings))->get();};
		if (profile) {
			profile[sql]++;
		}
	}

	//write("------passed catch block\n");

	#ifdef SLOW_QUERY_THRESHOLD
		float t = tm->peek();
		if (t > SLOW_QUERY_THRESHOLD) {
			werror("Slow query: %O\n%O\n%O\n", t, sql, bindings || ([]));
		}
	#endif

	completion->success(1);
	if (query_pending == completion) query_pending = 0;
	if (ex) {
		if (mixed st = objectp(ex) && ex->status_command_complete) ex = st;
		throw(ex);
	}

	return ret;

}


//Attempt to create all tables and alter them as needed to have all columns
__async__ void create_tables() {

		array cols = await(run_query(#"
			select table_name, column_name from information_schema.columns
			where table_schema = 'public'
			order by table_name, ordinal_position
		"));
		array alters = ({ });
		mapping (string:array(string)) creates = ([]);
		mapping (string:array(string)) havecols = ([]);
		foreach (cols, mapping col) havecols[col->table_name] += ({col->column_name});
		mapping (string:multiset) dependencies = ([]);
		foreach (tables; string tbname; array cols) {
			if (!havecols[tbname]) {
				//The table doesn't exist (rather has no cols). Create it from scratch.
				array extras = filter(cols, has_suffix, ";");
				array coldefs = cols - extras;
				dependencies[tbname] = (<>);
				foreach(coldefs, string col) {
					sscanf(col, "%*s references %[a-z_]", string tb);
					if (tb) dependencies[tbname][tb] = 1; // add a dep to the multiset by setting it to 1
					// eg dependencies["quotes"] is a multiset that will contain customers
				}
				creates[tbname] = ({
					sprintf("create table %s (%s)", tbname, coldefs * ", "),
				}) + extras;
				continue;
			}

			//If we have columns that aren't in the table's definition,
			//drop them. If the converse, add them. There is no provision
			//here for altering columns.
			string alter = "";
			multiset sparecols = (multiset)havecols[tbname];
			foreach (cols, string col) {
				if (has_suffix(col, ";") || has_prefix(col, " ")) continue;
				sscanf(col, "%s ", string colname);
				if (sparecols[colname]) sparecols[colname] = 0;
				else alter += ", add " + col;
			}
			//If anything hasn't been removed from havecols, it should be dropped.
			foreach (sparecols; string colname;) alter += ", drop " + colname;
			if (alter != "") alters += ({"alter table " + tbname + alter[1..]}); //There'll be a leading comma
			else write("Table %s unchanged\n", tbname);
		}
		// Now run the create statements (if any, dependencies first)
		array stmts = ({ });
		while(sizeof(creates)) {
			int created = 0;
			foreach (indices(creates), string tbname) {
				if (!sizeof(creates & dependencies[tbname])) {
					werror("Creating table %s\n", tbname);
					stmts += creates[tbname];
					m_delete(creates, tbname);
					created = 1;
				} else werror("Postponing table %s\n", tbname);
			}
			if (!created) {
				werror("Circular dependency in table creation: %O\n", creates);
				return;
			}
		}
		stmts += alters;
		if (sizeof(stmts)) {
			werror("Making changes: %O\n", stmts);
			await(run_query(stmts, ([])));
		}
}

void start_profiling() {
	profile_timer = System.Timer();
	profile = ([]);
}

void end_profiling(string action) {
	werror("%s complete in %.2fs. Queries: %O\n", action, profile_timer->peek(), profile);
	profile = 0;
}


protected void create(string name) {
	::create(name);
	G->G->DB = this;
	if (G->G->instance_config->pgsql_connection_string) {
		werror("Postgres DB Connecting\n");
		conn = Sql.Sql(G->G->instance_config->pgsql_connection_string);
		write("%O\n", conn);
	}
}
