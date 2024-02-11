fn main()
    let username = "otter";
    let email = "nvim";
    let password_hash = "pw";

    let user_id = sqlx::query_scalar!(
        r#"
        INSERT INTO "user" (username, email, password_hash)
            VALUES ($1, $2, $3)
        RETURNING
            user_id;
        "#,
        username,
        email,
        password_hash
    )
}
