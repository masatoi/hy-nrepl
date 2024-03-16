# sample module for testing lookup op


def hello_python(name):
    print("Hello, {}!".format(name))


def add1_python(n):
    """This is docstring"""
    return n + 1


class Bar(object):
    """Sample class Bar"""

    def __init__(self, x):
        self.x = x

    def get_x(self):
        return self.x
