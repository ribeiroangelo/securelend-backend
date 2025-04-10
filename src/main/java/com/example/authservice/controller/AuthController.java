package com.example.authservice.controller;

import com.example.authservice.entity.User;
import com.example.authservice.security.JwtUtil;
import com.example.authservice.service.UserService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.web.bind.annotation.*;
import com.google.common.cache.CacheBuilder;
import com.google.common.cache.CacheLoader;
import com.google.common.cache.LoadingCache;
import org.springframework.http.HttpStatus;
import jakarta.servlet.http.HttpServletRequest;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.ExecutionException;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private static final Logger logger = LoggerFactory.getLogger(AuthController.class);

    @Autowired
    private AuthenticationManager authenticationManager;

    @Autowired
    private UserService userService;

    @Autowired
    private JwtUtil jwtUtil;

    private final LoadingCache<String, Integer> attemptCache;
    private static final int MAX_ATTEMPTS = 5;
    private static final int BLOCK_DURATION_MINUTES = 15;

    public AuthController() {
        attemptCache = CacheBuilder.newBuilder()
                .expireAfterWrite(BLOCK_DURATION_MINUTES, TimeUnit.MINUTES)
                .build(new CacheLoader<>() {
                    @Override
                    public Integer load(String key) {
                        return 0;
                    }
                });
    }

    @PostMapping("/register")
    public ResponseEntity<User> register(@RequestBody User user) {
        logger.debug("Register request received: username={}, email={}", user.getUsername(), user.getEmail());
        User savedUser = userService.registerUser(user);
        logger.debug("User registered: id={}", savedUser.getId());
        return ResponseEntity.ok(savedUser);
    }

    @PostMapping("/login")
    public ResponseEntity<String> login(@RequestBody User user, HttpServletRequest request) {
        String ipAddress = getClientIP(request);
        
        try {
            if (isBlocked(ipAddress)) {
                logger.warn("Login attempt blocked for IP={}, too many attempts", ipAddress);
                return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
                    .body("Too many failed attempts. Please try again later.");
            }

            authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(user.getUsername(), user.getPassword()));
            
            // Reset counter on successful login
            attemptCache.put(ipAddress, 0);
            
            String token = jwtUtil.generateToken(user.getUsername());
            logger.debug("Login successful, token generated for username={}", user.getUsername());
            return ResponseEntity.ok(token);
        } catch (Exception e) {
            // Increment failed attempts counter
            registerFailedAttempt(ipAddress);
            logger.error("Login failed for username={}, IP={}: {}", user.getUsername(), ipAddress, e.getMessage());
            throw e;
        }
    }

    private boolean isBlocked(String key) {
        try {
            return attemptCache.get(key) >= MAX_ATTEMPTS;
        } catch (ExecutionException e) {
            return false;
        }
    }

    private void registerFailedAttempt(String key) {
        try {
            int attempts = attemptCache.get(key);
            attemptCache.put(key, attempts + 1);
        } catch (ExecutionException e) {
            attemptCache.put(key, 1);
        }
    }

    private String getClientIP(HttpServletRequest request) {
        String xfHeader = request.getHeader("X-Forwarded-For");
        if (xfHeader == null) {
            return request.getRemoteAddr();
        }
        return xfHeader.split(",")[0];
    }

    @GetMapping("/protected")
    public ResponseEntity<String> protectedEndpoint() {
        logger.debug("Protected endpoint accessed");
        return ResponseEntity.ok("This is a protected endpoint!");
    }
}