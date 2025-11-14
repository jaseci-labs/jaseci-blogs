from setuptools import setup, find_packages

setup(
    name='jac-blog-syntax',
    version='1.0.0',
    description='Jac syntax highlighter for blog',
    py_modules=['jac_syntax_highlighter'],
    install_requires=[
        'mkdocs-material>=9.0.0',
        'pymdown-extensions>=10.0',
        'pygments>=2.14.0',
        'mkdocs-video>=1.5.0',
        'starlette>=0.27.0',
        'uvicorn>=0.23.0',
        'watchdog>=3.0.0',
        'jaclang',
    ],
    entry_points={
        'pygments.lexers': [
            'jac = jac_syntax_highlighter:JacLexer',
        ],
    },
    classifiers=[
        'Development Status :: 4 - Beta',
        'Intended Audience :: Developers',
        'License :: OSI Approved :: MIT License',
        'Programming Language :: Python :: 3',
        'Topic :: Text Processing :: Linguistic',
    ],
)
