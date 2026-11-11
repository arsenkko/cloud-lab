import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL;
const VUS = parseInt(__ENV.VUS || '30');
const SHORT = __ENV.SHORT === '1';
const JSON_HEADERS = { headers: { 'Content-Type': 'application/json' } };

export const options = {
  stages: SHORT
    ? [
        { duration: '10s', target: VUS },
        { duration: '10s', target: VUS },
        { duration: '5s', target: 0 },
      ]
    : [
        { duration: '2m30s', target: VUS },
        { duration: '5m', target: VUS },
        { duration: '2m', target: 0 },
      ],
  summaryTrendStats: ['avg', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
};

export function setup() {
  const res = http.post(
    `${BASE_URL}/users`,
    JSON.stringify({ name: 'loadtest-user' }),
    JSON_HEADERS
  );
  return { userId: res.json('id') };
}

export default function (data) {
  const created = http.post(
    `${BASE_URL}/posts`,
    JSON.stringify({
      author_id: data.userId,
      title: `Post ${__VU}-${__ITER}`,
      body: 'Load test body',
    }),
    JSON_HEADERS
  );
  check(created, { 'post created (201)': (r) => r.status === 201 });
  if (created.status !== 201) {
    sleep(1);
    return;
  }
  const postId = created.json('id');

  for (let i = 0; i < 3; i++) {
    const list = http.get(`${BASE_URL}/posts`);
    check(list, { 'list ok (200)': (r) => r.status === 200 });

    const post = http.get(`${BASE_URL}/posts/${postId}`);
    check(post, { 'post ok (200)': (r) => r.status === 200 });

    const author = http.get(`${BASE_URL}/users/${data.userId}`);
    check(author, { 'author ok (200)': (r) => r.status === 200 });
  }
  sleep(1);
}