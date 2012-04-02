import contextlib


def append(view, text):
    """Appends text to view."""
    with in_one_edit(view) as edit:
        view.insert(edit, view.size(), text)


@contextlib.contextmanager
def in_one_edit(view):
    """Context manager to group edits in a view.

        Example:
            ...
            with in_one_edit(view):
                ...
            ...
    """
    try:
        edit = view.begin_edit()
        yield edit
    finally:
        view.end_edit(edit)


def has_sels(view):
    """Returns ``True`` if ``view`` has one selection or more.``
    """
    return len(view.sel()) > 0


def has_file_ext(view, ext):
    """Returns ``True`` if view has file extension ``ext``.
    ``ext`` may be specified with or without leading ``.``.
    """
    if not view.file_name(): return False
    if not ext.strip().replace('.', ''): return False
    
    if not ext.startswith('.'):
        ext = '.' + ext

    return view.file_name().endswith(ext)