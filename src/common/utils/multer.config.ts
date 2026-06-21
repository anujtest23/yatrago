import { diskStorage } from 'multer';
import { extname } from 'path';
import { BadRequestException } from '@nestjs/common';

export const imageMulterConfig = {
  storage: diskStorage({
    destination: './uploads',
    filename: (req, file, cb) => {
      const uniqueSuffix =
        Date.now() + '-' + Math.round(Math.random() * 1e9);
      cb(null, uniqueSuffix + extname(file.originalname));
    },
  }),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
  fileFilter: (req: any, file: Express.Multer.File, cb: any) => {
    if (!file.mimetype.match(/\/(jpg|jpeg|png|webp|pdf)$/)) {
      cb(new BadRequestException('Only images and PDFs are allowed'), false);
    } else {
      cb(null, true);
    }
  },
};