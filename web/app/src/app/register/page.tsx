import type { Metadata } from 'next';
import { RegisterDeviceClient } from './RegisterDeviceClient';

export const metadata: Metadata = {
  title: 'Register Device',
  description: 'Register an Omi device to approve web portal access.',
};

export default function RegisterDevicePage() {
  return <RegisterDeviceClient />;
}
