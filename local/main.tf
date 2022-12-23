provider "local" {
}

resource "local_file" "foo" {
  filename = "${path.module}/foo.txt"
  content  = data.local_file.bar.content
}

data "local_file" "bar" {
	filename = "${path.module}/bar.txt"
}

output "file_bar" {
	value=data.local_file.bar
}

