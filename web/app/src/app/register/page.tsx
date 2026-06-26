import type { Metadata } from 'next';
import { PairDeviceClient } from '../pair/PairDeviceClient';

export const metadata: Metadata = {
  title: 'Register Device',
  description: 'Register an Omi device to approve web portal access.',
};

export default function RegisterDevicePage() {
  return <PairDeviceClient mode="register" />;
}
