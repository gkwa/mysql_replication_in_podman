import dataclasses
import logging
import os
import pathlib
import stat
import subprocess
import typing

import jinja2
import yaml


@dataclasses.dataclass
class Executor:
    cmd: typing.List[str] = dataclasses.field(default_factory=list)
    outputs: typing.List[str] = dataclasses.field(default_factory=list)
    errors: typing.List[str] = dataclasses.field(default_factory=list)

    def run(self):
        proc = subprocess.Popen(
            self.cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

        try:
            outs, errs = proc.communicate(timeout=15)
        except subprocess.TimeoutExpired:
            proc.kill()
            outs, errs = proc.communicate()

        if errs:
            logging.warning(f"failed to run {self.cmd}, error: {errs.decode()}")
        else:
            logging.debug(f"ran ok: {self.cmd}")

        self.outputs = outs
        self.errors = errs


def shfmt(path: str = __file__):
    cmd: typing.List[str] = "shfmt -w -s -i 4".split()
    glob: str = "**/*.sh"

    basedir: pathlib.Path = pathlib.Path(path).parent.resolve()
    files = [str(c) for c in pathlib.Path(basedir).glob(glob)]
    cmd.extend(files)

    Executor(cmd).run()


def main():
    logging.basicConfig(level=logging.DEBUG)
    logger = logging.getLogger(__name__)

    manifest_path = pathlib.Path(__file__).parent.resolve() / "manifest.yml"

    with open(manifest_path, "r") as stream:
        try:
            manifest = yaml.safe_load(stream)
        except yaml.YAMLError as exc:
            print(exc)

    os.chdir(manifest_path.parent)  # to find templates

    env = jinja2.Environment(keep_trailing_newline=True)
    env.loader = jinja2.FileSystemLoader("templates")

    extension = ".sh"
    path = pathlib.Path(f"setup{extension}")
    tpl = env.get_template(f"{path.stem}.j2")
    rtpl = tpl.render(manifest=manifest, test_name=path.stem)
    path.write_text(rtpl)
    path.chmod(path.stat().st_mode | stat.S_IEXEC)

    extension = ".bats"
    path = pathlib.Path(f"test_statement_based_binlog_format{extension}")
    tpl = env.get_template(f"{path.stem}.j2")
    rtpl = tpl.render(manifest=manifest, test_name=path.stem)
    path.write_text(rtpl)
    path.chmod(path.stat().st_mode | stat.S_IEXEC)

    extension = ".bats"
    path = pathlib.Path(f"test_percona_checksums{extension}")
    tpl = env.get_template(f"{path.stem}.j2")
    rtpl = tpl.render(manifest=manifest, test_name=path.stem)
    path.write_text(rtpl)
    path.chmod(path.stat().st_mode | stat.S_IEXEC)

    extension = ".bats"
    path = pathlib.Path(f"test_fart{extension}")
    tpl = env.get_template(f"{path.stem}.j2")
    rtpl = tpl.render(manifest=manifest, test_name=path.stem)
    path.write_text(rtpl)
    path.chmod(path.stat().st_mode | stat.S_IEXEC)

    extension = ".bats"
    path = pathlib.Path(f"test_recover_from_bad_state{extension}")
    tpl = env.get_template(f"{path.stem}.j2")
    rtpl = tpl.render(manifest=manifest, test_name=path.stem)
    path.write_text(rtpl)
    path.chmod(path.stat().st_mode | stat.S_IEXEC)

    extension = ".bats"
    path = pathlib.Path(f"reset_data{extension}")
    tpl = env.get_template(f"{path.stem}.j2")
    rtpl = tpl.render(manifest=manifest, test_name=path.stem)
    path.write_text(rtpl)
    path.chmod(path.stat().st_mode | stat.S_IEXEC)

    shfmt()


if __name__ == "__main__":
    main()
