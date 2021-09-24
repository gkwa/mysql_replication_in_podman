import dataclasses
import logging
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


@dataclasses.dataclass
class ScriptExpander:
    extension: str
    prefix: str
    data: object
    jinja_env: jinja2.Environment
    path: pathlib.Path = dataclasses.field(init=False)

    def __post_init__(self):
        self.path = pathlib.Path(f"{self.prefix}.{self.extension}")

    def write(self):
        tpl = self.jinja_env.get_template(f"{self.path.stem}.j2")
        rtpl = tpl.render(data=self.data, test_name=self.path.stem)
        self.path.write_text(rtpl)
        self.set_executable()

    def set_executable(self):
        self.path.chmod(self.path.stat().st_mode | stat.S_IEXEC)


def main():
    logging.basicConfig(level=logging.DEBUG)
    logger = logging.getLogger(__name__)

    manifest_path = pathlib.Path(__file__).parent.resolve() / "manifest.yml"

    with open(manifest_path, "r") as stream:
        try:
            manifest = yaml.safe_load(stream)
        except yaml.YAMLError as exc:
            print(exc)

    env = jinja2.Environment(keep_trailing_newline=True)
    env.loader = jinja2.FileSystemLoader(manifest_path.parent / "templates/")

    ScriptExpander("sh", "setup", data=manifest, jinja_env=env).write()
    ScriptExpander("sh", "setup", data=manifest, jinja_env=env).write()
    ScriptExpander(
        "bats", "test_percona_checksums", data=manifest, jinja_env=env
    ).write()
    ScriptExpander("bats", "test_fart", data=manifest, jinja_env=env).write()
    ScriptExpander(
        "bats", "test_recover_from_bad_state", data=manifest, jinja_env=env
    ).write()
    ScriptExpander("bats", "test_reset_data", data=manifest, jinja_env=env).write()
    ScriptExpander(
        "bats", "test_statement_based_binlog_format", data=manifest, jinja_env=env
    ).write()

    shfmt()


if __name__ == "__main__":
    main()
