#! /usr/bin/env python

from setuptools import find_packages, setup

setup(name="HyREPL",
      version="0.2.0",
      install_requires=['hy==0.27.0', 'hyrule==0.4.0', 'toolz'],
      dependency_links=[
          'https://github.com/hylang/hy/archive/master.zip#egg=hy-0.27.0',
      ],
      packages=find_packages(exclude=['tests']),
      package_data={
          'HyREPL': ['*.hy'],
          'HyREPL.middleware': ['*.hy'],
      },
      author="Morten Linderud, Gregor Best",
      author_email="morten@linderud.pw, gbe@unobtanium.de",
      long_description="nREPL implementation in Hylang",
      license="MIT",
      scripts=["bin/hyrepl"],
      url="https://github.com/masatoi/HyREPL",
      platforms=['any'],
      classifiers=[
          "Development Status :: 3 - Alpha",
          "Intended Audience :: Developers",
          "Operating System :: OS Independent",
          "Programming Language :: Lisp",
          "Topic :: Software Development :: Libraries",
      ])
