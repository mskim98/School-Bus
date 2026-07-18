# --- 빌드 단계: Next.js 프로덕션 빌드 ---
FROM node:20-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

# --- 실행 단계 ---
FROM node:20-alpine
WORKDIR /app
ENV NODE_ENV=production
# 빌드 산출물과 런타임 의존성 복사
COPY --from=build /app/package.json /app/package-lock.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/.next ./.next
COPY --from=build /app/next.config.js ./
EXPOSE 3000
CMD ["npm", "start"]
