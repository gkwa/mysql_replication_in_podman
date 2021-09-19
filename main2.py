import pathlib
import stat

import jinja2
import yaml

manifest_path = pathlib.Path(__file__).parent.resolve() / "manifest.yml"

with open(manifest_path, "r") as stream:
    try:
        manifest = yaml.safe_load(stream)
    except yaml.YAMLError as exc:
        print(exc)

env = jinja2.Environment()
env.loader = jinja2.FileSystemLoader("templates")

tmpl = env.get_template("setup.j2")
path = pathlib.Path("setup.sh")
expanded = tmpl.render(manifest=manifest, test_name=path.stem)
path.write_text(expanded)
path.chmod(path.stat().st_mode | stat.S_IEXEC)

path = pathlib.Path("test_statement_based_binlog_format.bats")
tmpl = env.get_template(f"{path.stem}.j2")
expanded = tmpl.render(manifest=manifest, test_name=path.stem)
path.write_text(expanded)
path.chmod(path.stat().st_mode | stat.S_IEXEC)

path = pathlib.Path("test_percona_checksums.bats")
tmpl = env.get_template(f"{path.stem}.j2")
expanded = tmpl.render(manifest=manifest, test_name=path.stem)
path.write_text(expanded)
path.chmod(path.stat().st_mode | stat.S_IEXEC)

path = pathlib.Path("test_fart.bats")
tmpl = env.get_template(f"{path.stem}.j2")
expanded = tmpl.render(manifest=manifest, test_name=path.stem)
path.write_text(expanded)
path.chmod(path.stat().st_mode | stat.S_IEXEC)

path = pathlib.Path("test_recover_from_bad_state.bats")
tmpl = env.get_template(f"{path.stem}.j2")
expanded = tmpl.render(manifest=manifest, test_name=path.stem)
path.write_text(expanded)
path.chmod(path.stat().st_mode | stat.S_IEXEC)
