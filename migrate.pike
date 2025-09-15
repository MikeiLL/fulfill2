

void main() {
  string tables = Stdio.read_file("create_table.sql");
  foreach (tables / "\n", string line) {
    if (line == "") continue;
    if (line == String.trim(line)) {
      // no indendataion, must be a table name
      write("\n\t}),\n\t%O: ({\n", line);
    } else {
      // must be a table definition
      write("\t\t%O,\n", String.trim(line));
    }
  }
}
