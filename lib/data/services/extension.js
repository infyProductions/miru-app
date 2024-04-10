class Element {
    constructor(content, selector) {
        this.content = content;
        this.selector = selector || "";
    }
    async querySelector(selector) {
        return new Element(await this.execute(), selector);
    }

    async execute(fun) {
        await DartBridge.sendMessage("querySelector", JSON.stringify([this.content, this.selector, fun]));
    }

    async removeSelector(selector) {
        this.content = await sendMessage(
            "removeSelector",
            JSON.stringify([await this.outerHTML, selector])
        );
        return this;
    }

    async getAttributeText(attr) {
        return await sendMessage(
            "getAttributeText",
            JSON.stringify([await this.outerHTML, this.selector, attr])
        );
    }

    get text() {
        return this.execute("text");
    }

    get outerHTML() {
        return this.execute("outerHTML");
    }

    get innerHTML() {
        return this.execute("innerHTML");
    }
}
class XPathNode {
    constructor(content, selector) {
        this.content = content;
        this.selector = selector;
    }

    async excute(fun) {
        return await sendMessage(
            "queryXPath",
            JSON.stringify([this.content, this.selector, fun])
        );
    }

    get attr() {
        return this.excute("attr");
    }

    get attrs() {
        return this.excute("attrs");
    }

    get text() {
        return this.excute("text");
    }

    get allHTML() {
        return this.excute("allHTML");
    }

    get outerHTML() {
        return this.excute("outerHTML");
    }
}

// 重写 console.log
console.log = function (message) {
    if (typeof message === "object") {
        message = JSON.stringify(message);
    }
    DartBridge.sendMessage("log$className", JSON.stringify([message.toString()]));
};
class Extension {
    package = "${extension.package}";
    name = "${extension.name}";
    // 在 load 中注册的 keys
    settingKeys = [];

    querySelector(content, selector) {
        return new Element(content, selector);
    }
    async request(url, options) {
        options = options || {};
        options.headers = options.headers || {};
        const miruUrl = options.headers["Miru-Url"] || "${extension.webSite}";
        options.method = options.method || "get";
        var message = null
        const waitForChange = new Promise(resolve => {
            DartBridge.setHandler("request$className", async (res) => {
                try {
                    message = JSON.parse(res);
                } catch (e) {
                    message = res;
                }
                resolve();
            });
        });

        DartBridge.sendMessage("request$className", JSON.stringify([miruUrl + url, options, "${extension.package}"]));
        await waitForChange;
        console.log("Dart Bridge Passed");
        return message;
    }
    queryXPath(content, selector) {
        return new XPathNode(content, selector);
    }
    async querySelectorAll(content, selector) {
        const elements = [];
        const waitForChange = new Promise(resolve => {
            DartBridge.setHandler("querySelectorAll", async (arg) => {

                const message = JSON.parse(arg);
                for (const e of message) {
                    elements.push(new Element(e, selector));
                }
                resolve();
            })
        });
        DartBridge.sendMessage("querySelectorAll$className", JSON.stringify([content, selector]));
        await waitForChange;
        return elements;
    }
    async getAttributeText(content, selector, attr) {
        return await sendMessage(
            "getAttributeText",
            JSON.stringify([content, selector, attr])
        );
    }
    latest(page) {
        throw new Error("not implement latest");
    }
    search(kw, page, filter) {
        throw new Error("not implement search");
    }
    createFilter(filter) {
        throw new Error("not implement createFilter");
    }
    detail(url) {
        throw new Error("not implement detail");
    }
    watch(url) {
        throw new Error("not implement watch");
    }
    checkUpdate(url) {
        throw new Error("not implement checkUpdate");
    }
    async getSetting(key) {
        return sendMessage("getSetting", JSON.stringify([key]));
    }
    async registerSetting(settings) {
        console.log(JSON.stringify([settings]));
        this.settingKeys.push(settings.key);
        return sendMessage("registerSetting", JSON.stringify([settings]));
    }
    async load() { }
}

async function stringify(callback) {
    const data = await callback();
    return typeof data === "object" ? JSON.stringify(data, 0, 2) : data;
}
