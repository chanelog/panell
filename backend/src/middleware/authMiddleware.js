const jwt = require('jsonwebtoken');

function auth(req, res, next) {
    const token = req.header('Authorization').replace('Bearer ', '');
    if (!token) return res.sendStatus(401);

    jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
        if (err) return res.sendStatus(403);
        req.user = user;
        next();
    });
}

module.exports = auth;