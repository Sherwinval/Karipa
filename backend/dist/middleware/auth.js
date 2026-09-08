import jwt from 'jsonwebtoken';
export function requireAuth(req, res, next) {
    const header = req.header('authorization');
    const token = header?.startsWith('Bearer ') ? header.slice(7) : undefined;
    if (!token || !process.env.JWT_SECRET) {
        res.status(401).json({ success: false, message: 'Authentication required' });
        return;
    }
    try {
        const payload = jwt.verify(token, process.env.JWT_SECRET);
        if (typeof payload !== 'object' || payload === null || typeof payload.sub !== 'string') {
            throw new Error('Invalid token subject');
        }
        req.userId = BigInt(payload.sub);
        next();
    }
    catch {
        res.status(401).json({ success: false, message: 'Invalid or expired token' });
    }
}
