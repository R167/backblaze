# General best practices coding guide

## Overall Principals (in order of importance)

1. Two spaces to indent. Be anal about this.
2. Write code in English.
3. Code must work.
4. Code must be easy to understand.
5. Critical code should be efficient.
6. Try to follow the [GitHub Ruby Style Guide](https://github.com/styleguide/ruby). In general it's pretty good.
7. **Avoid religious wars. They're too bloody and everyone goes to hell in the end.**

After that, let's all just try to get along. Seriously, we all have our preferred coding styles and the existing codebase has had many hands in it over the years. The goal is to write good, clear code. After that, we are a business and the goal is to build a profitable product. Don't waste time on things that don't support that end.

Follow the guidelines. Don't waste time cleaning up coding just because you think it could be prettier. Learn to love your neighbor's code otherwise he'll just up and rewrite your code when you aren't looking.

## In this repo specifically

We're using the style guide ruleset from [StandardRB](https://github.com/testdouble/standard). This is good because it's a fairly minimal ruleset that avoids getting too anal about things like line length, etc. There's a couple things I would _slightly_ want to change if I had the choice, but honestly half the beauty of StandardRB is "Here's the rules. They're reasonably sane, so just live with it." The only exception I am making to this is disabling their "semantic block" rule. If your call is too complicated to fit in a one line chain like `ret_value = 8.times.map { |v| v * 2 }.join(" ")`, and you needed a multiline block, it should probably just be its own method then anyways.

I also particularly like that it settles on the "just use double quotes" cause I've had single quotes bite me on accident way too many times in the past.

While there is no line length limit, for readability, try to keep lines under 120 characters. If you're writing code on an 80x24 char console... why? That said, still try and keep things reasonable and don't try to make everything a 100 character Java class name or 18 different method calls all chained together, cause that's just not readable.

## Further Notes

NOTE: The following sections are retained from the original coding guide. Most of this isn't applicable to this repository (e.g. standard for documenting methods is higher cause make it clear how the gem works), or it is specifically about Rails. Regardless, I like it, so heres the rest

### Things To Do

1. Add a comment at the top of each class file explaining what it is for. Even if you think it's obvious. You don't have to write a novel, usually a sentence is more than enough.
2. Add a comment before a method where it isn't patently obvious what it does or if it has some sort of side effect. You'll find doing so pays excellent dividends when you don't have to keep answering the same questions over and over.
3. Add a comment to code when you do something that doesn't look right. You know which code this. Often it's an optimization or hack needed to avoid a bug. Let the world that you do indeed know what you're doing and are not in fact a clinical idiot whose code needs to be constantly rewritten.
4. Use protected and private methods for methods that don't need to be called by other classes. Otherwise you'll need to write tests for them and who wants to do that? Keep the public API of your classes small.
5. Logically group like classes inside modules. Especially in the models directory. That thing can get huge if doesn't have an subdirectories.
6. Use descriptive names for classes, methods, and variables. We all hate writing documentation and you probably aren't going to do it anyway, so let's make sure most things are self documenting. Of course we don't want to be zealots about this. Using a short variable name inside a single line iterator is perfectly fine.
7. Follow existing patterns in the code and accepted by the Rails community.
8. Pay attention to deprecated code and don't add more of it.
9. Don't be anal about the 80 column limit.
10. Use Hash parameters when more than three arguments are needed in a method.
11. When things go wrong and you fix it, make sure it doesn't happen again. Write a test. Write a comment. Whatever it takes.

### Things To Avoid

1. Don't make wholesale changes to existing code just to match a preferred style. If you need to edit a method in a large class file, don't go and refactor the whole file just to match your coding style. Doing so just adds to the scope of your work and makes reviewing the change more challenging.
2. Don't troll all the commits and suggesting minor style changes. I'm pretty sure you have more important things to do. So does everyone else who ends up reading and then adding to the discussion.
3. Don't worry about how elegant the code looks. Not every line can be a masterpiece and sometimes you need to make compromises. It's code. Is it clear? Does it work? Great! Move on.
4. Don't add new architecture patterns because they sound neat on a blog post. We need to keep the code base understandable and stable and adding the newest, shiniest toys doesn't always serve this end. Major changes need to be justified to the business.
5. Don't set up your editor to automatically correct any deviations from a code style. These tools can end up making mass changes that make reviewing changes very difficult.

### Miscellaneous Tips

1. Use 'preload' instead of 'includes' on ActiveRecord relations. Rails will do the wrong thing if you let it. I promise.

### Credits

Originally provided by [Brian Durand](https://github.com/bdurand)
