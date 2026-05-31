import Foundation

struct GetCategoriesTool: Tool {
    let name = "get_categories"
    let description = "List all configured categories."
    let kind: ToolKind = .read
    var parameters: JSONValue {
        JSONSchemaBuilder.object(properties: [
            "include_archived": JSONSchemaBuilder.boolean("Include archived (default false)")
        ])
    }

    func run(arguments args: JSONValue, context ctx: ToolContext) async throws -> JSONValue {
        let inc = args["include_archived"]?.boolValue ?? false
        let cats = try ctx.categoryRepo.all(includeArchived: inc)
        return .array(cats.map { c in
            .object([
                "id": .string(c.id.uuidString),
                "name": .string(c.name),
                "color": .string(c.colorHex),
                "icon": .string(c.systemImage),
                "archived": .bool(c.archived)
            ])
        })
    }
}

struct CreateCategoryTool: Tool {
    let name = "create_category"
    let description = "Create a new category."
    let kind: ToolKind = .write
    var parameters: JSONValue {
        JSONSchemaBuilder.object(
            properties: [
                "name": JSONSchemaBuilder.string("Category name"),
                "color": JSONSchemaBuilder.string("Hex color #RRGGBB (default #888888)"),
                "icon": JSONSchemaBuilder.string("SF Symbol name (default 'tag')")
            ],
            required: ["name"]
        )
    }

    func run(arguments args: JSONValue, context ctx: ToolContext) async throws -> JSONValue {
        guard let name = ToolArgs.string(args, "name"), !name.isEmpty else {
            throw ToolError.missingArgument("name")
        }
        if (try ctx.categoryRepo.findByName(name)) != nil {
            throw ToolError.invalidArgument("name", reason: "already exists")
        }
        let c = Category(
            name: name,
            colorHex: ToolArgs.string(args, "color") ?? "#888888",
            systemImage: ToolArgs.string(args, "icon") ?? "tag"
        )
        try ctx.categoryRepo.add(c)
        return .object([
            "id": .string(c.id.uuidString),
            "name": .string(c.name)
        ])
    }
}

struct GetPaymentMethodsTool: Tool {
    let name = "get_payment_methods"
    let description = "List all configured payment methods."
    let kind: ToolKind = .read
    var parameters: JSONValue {
        JSONSchemaBuilder.object(properties: [
            "include_archived": JSONSchemaBuilder.boolean("Include archived (default false)")
        ])
    }

    func run(arguments args: JSONValue, context ctx: ToolContext) async throws -> JSONValue {
        let inc = args["include_archived"]?.boolValue ?? false
        let items = try ctx.paymentMethodRepo.all(includeArchived: inc)
        return .array(items.map { pm in
            .object([
                "id": .string(pm.id.uuidString),
                "name": .string(pm.name),
                "kind": .string(pm.kind.rawValue),
                "archived": .bool(pm.archived)
            ])
        })
    }
}

struct CreatePaymentMethodTool: Tool {
    let name = "create_payment_method"
    let description = "Create a new payment method."
    let kind: ToolKind = .write
    var parameters: JSONValue {
        JSONSchemaBuilder.object(
            properties: [
                "name": JSONSchemaBuilder.string("Display name"),
                "kind": JSONSchemaBuilder.string(
                    "Kind",
                    enumValues: PMKind.allCases.map(\.rawValue)
                )
            ],
            required: ["name", "kind"]
        )
    }

    func run(arguments args: JSONValue, context ctx: ToolContext) async throws -> JSONValue {
        guard let name = ToolArgs.string(args, "name"), !name.isEmpty else {
            throw ToolError.missingArgument("name")
        }
        guard let kindStr = ToolArgs.string(args, "kind"),
              let kind = PMKind(rawValue: kindStr) else {
            throw ToolError.invalidArgument("kind", reason: "invalid value")
        }
        if (try ctx.paymentMethodRepo.findByName(name)) != nil {
            throw ToolError.invalidArgument("name", reason: "already exists")
        }
        let pm = PaymentMethod(name: name, kind: kind)
        try ctx.paymentMethodRepo.add(pm)
        return .object([
            "id": .string(pm.id.uuidString),
            "name": .string(pm.name),
            "kind": .string(pm.kind.rawValue)
        ])
    }
}
