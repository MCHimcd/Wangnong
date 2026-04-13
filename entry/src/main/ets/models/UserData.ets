/**
 * Purpose: 收敛认证与用户资料接口使用的基础数据结构。
 * Responsibilities: 定义登录响应、用户资料和通用 BaseResponse 包装类型。
 * Flow: HttpService 的认证与资料接口返回这些类型，页面据此更新登录态和个人资料。
 * Dependencies: 被 LoginPage、ProfileView、Settings 相关页面和 HttpService 使用。
 * Input: 后端认证与用户资料接口返回值。
 * Output: 前端类型系统可直接约束的接口定义。
 */
export interface LoginResponse {
  token: string;
  expires_in: number;
}

export interface UserProfile {
  userId: string;
  userName: string;
  gender: string;
  birthDate: string;
  avatarSrc: string;
  role: string;
}

export interface BaseResponse<T> {
  code: number;
  message: string;
  data: T;
}
