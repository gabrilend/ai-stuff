**Project: Ouroboros**
======================

![Build Status](https://dev.azure.com/OuroDev/Source/_apis/build/status/Volume%202%20Source?branchName=develop)

Prerequisite Software
=====================

Building requires [Visual Studio 2019](https://visualstudio.microsoft.com/vs/). The Community edition will work fine.

If you just to run a server, you will also need [SQL Server 2017](https://www.microsoft.com/en-us/sql-server/sql-server-2017). Any version at least >= SQL Server 2008 will work fine.  
[SQL Server Management Studio](https://docs.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms?view=sql-server-2017) should be installed as well to aid in setting up the database.

Download the necessary data archives from [links posted on the wiki](https://wiki.ourodev.com/Magnet_Links). Specifically "Volume 2 Issue 1.1 Server Data" and "Volume 2 Issue 1.1 Server Piggs".

Development Guide
=================
Coding Convention
-----------------

* **DO** use `const` and `static` and visibility modifiers to scope exposure of
   variables and methods as much as possible.

* **DON'T** use global variables where possible.

Style Guide
-----------

### Editor configuration with `EditorConfig`

For all C/C++ and C# files (`*.c`, `*.cpp`, `*.h`, `*.hpp` and `*.cs`), we use [EditorConfig](https://editorconfig.org/)
to apply our editor configuration rules to files. The Visual Studio 2019 IDE automatically picks
up rules specified in [.editorconfig](./.editorconfig) and applies the settings to modified code.

### Automated Formatting with `clang-format`

For all C/C++ files (`*.c`, `*.cpp`, `*.h`and `*.hpp`), we use `clang-format`
to apply our code formatting rules to **NEW** files. After adding new C/C++ files and
before merging, be sure to run `clang-format` by invoking it from the IDE of your choice.
In case of Visual Studio 2019 formatting is performed by _`File->Advanced->Format Document`_
or hitting _`Ctrl+K`_, _`Ctrl+D`_ (type _`Ctrl+K`_, AND THEN _`Ctrl+D`_ as it is a sequence).

This allows us apply formatting choices such as the use of [Allman style](
http://en.wikipedia.org/wiki/Indent_style#Allman_style) braces and the 160
character column width consistently.

Please stage the formatting changes with your commit, instead of making an extra
"Format Code" commit.

The [.clang-format](./.clang-format) file describes the style that is enforced
by invoking `clang-format`, which is based off the LLVM style with modifications closer to
the default Visual Studio style. See [clang-format style options](
http://releases.llvm.org/8.0.0/tools/clang/docs/ClangFormatStyleOptions.html)
for details.

### Naming Conventions

Naming conventions we use that are not automated include:

1. Don't use Hungarian notation (https://en.wikipedia.org/wiki/Hungarian_notation).
2. Use `camelCase` for variable, member/field, and function names.
3. Use `PascalCase` for user defined data types.
4. Use `UPPER_SNAKE_CASE` for macro names and constants.
5. Prefer `lower_snake_case` file names for headers and sources.
6. Prefer full words for names over contractions (i.e. `memoryContext`, not
   `memCtx`).
7. Use names with one trailing underscores (`_`) to indicate internal and private fields
   (e.g. `privateField_`).
8. Define variables as close as possible to their usage.

Above all, if a file happens to differ in style from these guidelines (e.g.
private members are named `m_member` rather than `member_`), the existing style
in that file takes precedence.

For other files (`*.asm`, `*.S`, etc.) our current best guidance is consistency:

- When editing files, keep new code and changes consistent with the style in the
  files.
- For new files, it should conform to the style for that component.

### Example code:

```c
// C99 or higher
#include <stdio.h>
#include <stdbool.h>

// Use PascalCase for user defined data types
typedef struct Node
{
    struct Node* next;      // Use camelCase for members/fields
    struct Node* prev;      // Use camelCase for members/fields
} Node;

// Use PascalCase for user defined data types
typedef struct Head
{
    Node list;              // Use camelCase for members/fields
    size_t count;           // Use camelCase for members/fields    
} Head;

// Use camelCase for function names
inline Node* initializeNode(Node* node)
{
    node->next = node->prev = node;
    return node;
}

// Use camelCase for function names
Head* initializeHead(Head* head)
{
    initializeNode(&head->list);
    head->count = 0;
    return head;
}

// Use camelCase for function names
inline size_t getSize(const Head* head)
{
    return head->count;
}

// Use camelCase for function names
inline bool isEmpty(const Head* head)
{
    return head->count == 0;
}

// Use camelCase for function names
Node* addNode(Head* head, Node* node)
{
    node->prev = head->list.prev;
    node->next = &head->list;
    head->list.prev->next = node;
    head->list.prev = node;
    ++head->count;
    return node;
}

// Use camelCase for function names
Node* removeNode(Head* head, Node* node)
{
    if (!isEmpty(head))
    {
        node->prev->next = node->next;
        node->next->prev = node->prev;
        initializeNode(node);
        --head->count;
    }
    return node;
}

// Use PascalCase for user defined data types
typedef struct Mender
{
    Node node;              // Use camelCase for members/fields
    const char* name;       // Use camelCase for members/fields
} Mender;

int main()
{
    // Use camelCase for variables
    Head listHead;
    initializeHead(&listHead);

    // Define variables as close as possible to their usage
    Mender clowd = { .node = {&clowd.node, &clowd.node},.name = "clowd" };
    addNode(&listHead, &clowd.node);

    Mender pazaz = { .node = {&pazaz.node, &pazaz.node},.name = "Pazaz" };
    addNode(&listHead, &pazaz.node);

    Mender cattan = { .node = {&cattan.node, &cattan.node},.name = "Cattan" };
    addNode(&listHead, &cattan.node);

    printf("List contains %zu menders\n", getSize(&listHead));

    for (const Node* current = listHead.list.next; current != &listHead.list; current = current->next)
    {
        const Mender* mender = (const Mender*)current;
        printf("Mender name is: '%s'\n", mender->name);
    }

    while (!isEmpty(&listHead))
    {
        printf("Removed mender '%s'\n", ((const Mender*)removeNode(&listHead, listHead.list.next))->name);
    }

    printf("List is %s\n", isEmpty(&listHead) ? "empty" : "not empty");

    return 0;
}
```

Building Servers and Client
=========================== 

## Downloading a Pre-built Archive

Build pipelines are triggered upon every commit to `master` and `develop`. You can find their output at [https://build.ourodev.com](build.ourodev.com).  
Skip to #2 if you use this option.

## 1) Building from Source

- Open `build/vs2019/master.sln`. Build against your chosen target platform and configuration.

## 2) Setting up SQL Server

- Enable TCP/IP in SQL Configuration Manager.
- Restart the SQL Server service.
- Create the necessary databases in SSMS using the schemas from `Assets/DBSchemas/`.
- If using an AuthServer, set up a File DSN with permissions to `cohauth`.

## 3) Running the Servers

Navigate to the `bin/` directory.
- Copy `Assets/ConfigFiles/*` here.
- Extract `data-v2i1.1.7z` and `piggs-v2i1.1.7z` here.
- Edit all server configuration files in `data/server/db/`. You should update any SqlLogin entries and define any server-specific variables you wish to use
- Run `MapServer.exe -productionmode -templates`
- If using an AuthServer, run `AuthServer.exe`
- Run `DBServer.exe -startall`.
- Run `Launcher.exe`.

Once all the services are up you should be able to connect using `Ouroboros.exe`. Keep an eye on things using ServerMonitor.

And most importantly, defer to [the wiki](https://wiki.ourodev.com) if you need in-depth instructions :)

<a href="https://wiki.ourodev.com/OuroDev_Discord"><img style="vertical-align:middle" src="https://discordapp.com/assets/fc0b01fe10a0b8c602fb0106d8189d9b.png" alt="Discord" height="30px" /></a>
