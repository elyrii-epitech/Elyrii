import UserService from "./src/service/user.service";

const userService = new UserService();

Bun.serve({
    port: Number(Bun.env.USER_PORT) || 3005,
    fetch: userService.getRouter.fetch.bind(userService.getRouter),
    error(error) {
        console.error("[User Service Error]", error);
        return new Response("Internal Server Error", { status: 500 });
    }
});

console.log(`[User Service] Running on port ${Bun.env.USER_PORT || 3005}`);
