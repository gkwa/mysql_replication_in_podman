import logging
import os
import pathlib
import stat
import subprocess
import typing

import jinja2
import yaml


def shfmt(path: str = __file__):
    cmd: typing.List[str] = "shfmt -w -s -i 4".split()
    glob: str = "**/*.sh"

    basedir: pathlib.Path = pathlib.Path(path).parent.resolve()
    files = [str(c) for c in pathlib.Path(basedir).glob(glob)]
    cmd.extend(files)

    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    try:
        outs, errs = proc.communicate(timeout=15)
    except subprocess.TimeoutExpired:
        proc.kill()
        outs, errs = proc.communicate()

    if errs:
        logging.warning(f"failed to run {cmd}, error: {errs.decode()}")
    else:
        logging.debug(f"ran ok: {cmd}")


def main():
    logging.basicConfig(level=logging.DEBUG)
    logger = logging.getLogger(__name__)

    manifest_path = pathlib.Path(__file__).parent.resolve() / "manifest.yml"

    with open(manifest_path, "r") as stream:
        try:
            manifest = yaml.safe_load(stream)
        except yaml.YAMLError as exc:
            print(exc)

    env = jinja2.Environment()
    os.chdir(manifest_path.parent)  # to find templates
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

    path = pathlib.Path("reset_data.bats")
    tmpl = env.get_template(f"{path.stem}.j2")
    expanded = tmpl.render(manifest=manifest, test_name=path.stem)
    path.write_text(expanded)
    path.chmod(path.stat().st_mode | stat.S_IEXEC)

    shfmt()


if __name__ == "__main__":
    main()
