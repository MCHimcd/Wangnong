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
}

export interface BaseResponse<T> {
  code: number;
  message: string;
  data: T;
}
