You're a senior software architect and the plan is to build a native macOS desktop application that supports multiple API docset, multiple versions of each docset. So a docset is for example, Ruby on Rails API document or Ruby API document. It should support multiple docset and multiple versions of it, such as for instance, the Ruby docset, we should be able to install and activate version 3.4, version 4.0 and so on.

The UI should be pretty simple. Two columns, one sidebar, one search bar. And when I search for a method, then it should filter the method. It should let me click on the method and reveal the content of that method as per the API.

It needs to be scalable to support future docsets. Each docset has its own source, content and structure. Therefore, they need to be tailored differently. Make it scalable. Make sure you have a JSON pipeline and parser pipeline for each type of docset and version.

It should build a lightweight macOS desktop application. No dependency. I don't want to use Xcode if possible. It should use GitHub Action for compiling the application and attach through repo repleases.

No plan to distribute the application. It's purely for internal purpose. At the end return the project, GitHub repo, compiled version, a CI which includes the build step. Make it all without any intervention.

You can copy the UI from Dash application. Here's the link. https://kapeli.com/dash
